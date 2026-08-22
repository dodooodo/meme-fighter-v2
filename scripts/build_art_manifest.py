#!/usr/bin/env python3
"""Validate and execute one deterministic manifest of presentation asset jobs."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Optional


SCHEMA_VERSION = 1
JOB_TYPES = {"base_fighter", "effect", "mode_fighter", "ultimate_screen"}
BASE_CHARACTERS = {"magic_orange_cat", "salad_cat"}
EFFECT_PACK_TYPES = {"PROJECTILE", "WORLD_EFFECT", "HAZARD", "ATTACHMENT"}
JOB_ID_RE = re.compile(r"[a-z][a-z0-9_-]*\Z")
ASSET_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*\Z")
COMMON_FIELDS = {"id", "type"}
FIELDS_BY_TYPE = {
    "base_fighter": COMMON_FIELDS | {"character", "source"},
    "effect": COMMON_FIELDS | {"spec", "source_root", "output_root"},
    "mode_fighter": COMMON_FIELDS | {"spec", "source_root", "output_root"},
    "ultimate_screen": COMMON_FIELDS | {"spec", "source_root", "output_root"},
}
REQUIRED_BY_TYPE = {
    "base_fighter": {"id", "type", "character", "source"},
    "effect": {"id", "type", "spec"},
    "mode_fighter": {"id", "type", "spec"},
    "ultimate_screen": {"id", "type", "spec"},
}


def _contained_path(project_root: Path, value: Any, label: str, must_exist: bool) -> Path:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be a non-empty repository-relative path")
    raw = Path(value)
    if raw.is_absolute():
        raise ValueError(f"{label} must be repository-relative: {value}")
    resolved = (project_root / raw).resolve()
    try:
        resolved.relative_to(project_root.resolve())
    except ValueError as exc:
        raise ValueError(f"{label} escapes the repository: {value}") from exc
    if must_exist and not resolved.exists():
        raise ValueError(f"{label} does not exist: {value}")
    return resolved


def _source_path(source_root: Path, project_root: Path, value: Any, label: str) -> Path:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label} must be a non-empty path")
    raw = Path(value)
    if raw.is_absolute():
        raise ValueError(f"{label} must be relative to its source root: {value}")
    resolved = (source_root / raw).resolve()
    try:
        resolved.relative_to(project_root.resolve())
    except ValueError as exc:
        raise ValueError(f"{label} escapes the repository: {value}") from exc
    if not resolved.is_file():
        raise ValueError(f"{label} does not exist: {resolved.relative_to(project_root)}")
    return resolved


def _contained_output_path(project_root: Path, value: Any, label: str) -> Path:
    resolved = _contained_path(project_root, value, label, False)
    relative = resolved.relative_to(project_root.resolve())
    parts = relative.parts
    if len(parts) < 3 or parts[:2] != ("assets", "characters"):
        raise ValueError(f"{label} must be below assets/characters/<character_asset_key>")
    return resolved


def _asset_id(value: Any, label: str) -> str:
    if not isinstance(value, str) or ASSET_ID_RE.fullmatch(value) is None:
        raise ValueError(f"{label} must match {ASSET_ID_RE.pattern}")
    return value


def _path_from_source_spec(value: Any, label: str) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict) and isinstance(value.get("path"), str):
        return value["path"]
    raise ValueError(f"{label} must be a path string or object with path")


def _validate_spec_sources(job: dict[str, Any], spec_path: Path, project_root: Path) -> None:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    if not isinstance(spec, dict):
        raise ValueError(f"job {job['id']} spec root must be an object")
    source_root = (
        _contained_path(project_root, job["source_root"], f"job {job['id']} source_root", True)
        if "source_root" in job
        else spec_path.parent.resolve()
    )
    if not source_root.is_dir():
        raise ValueError(f"job {job['id']} source_root must be a directory")

    source_values: list[tuple[Any, str]] = []
    if job["type"] == "effect":
        if spec.get("pack_type") not in EFFECT_PACK_TYPES:
            raise ValueError(f"job {job['id']} effect spec has invalid pack_type")
        _asset_id(spec.get("character_asset_key", "shared"), f"job {job['id']} character_asset_key")
        effect_id = spec.get("effect_id", spec.get("attachment_id", ""))
        _asset_id(effect_id, f"job {job['id']} effect_id/attachment_id")
        if "frames" in spec:
            frames = spec["frames"]
            if not isinstance(frames, list) or not frames:
                raise ValueError(f"job {job['id']} frames must be a non-empty array")
            source_values.extend((value, f"job {job['id']} frames[{index}]") for index, value in enumerate(frames))
        elif "source" in spec:
            source_values.append((spec["source"], f"job {job['id']} source"))
        else:
            raise ValueError(f"job {job['id']} effect spec requires frames or source")
    elif job["type"] == "mode_fighter":
        if spec.get("pack_type") != "MODE_FIGHTER":
            raise ValueError(f"job {job['id']} mode spec pack_type must be MODE_FIGHTER")
        _asset_id(spec.get("character_asset_key"), f"job {job['id']} character_asset_key")
        _asset_id(spec.get("character_id"), f"job {job['id']} character_id")
        _asset_id(spec.get("mode_id"), f"job {job['id']} mode_id")
        animations = spec.get("animations")
        if not isinstance(animations, list) or not animations:
            raise ValueError(f"job {job['id']} mode spec requires animations")
        for animation_index, animation in enumerate(animations):
            if not isinstance(animation, dict):
                raise ValueError(f"job {job['id']} animation {animation_index} must be an object")
            if "frames" in animation:
                frames = animation["frames"]
                if not isinstance(frames, list) or not frames:
                    raise ValueError(f"job {job['id']} animation {animation_index} frames must be non-empty")
                source_values.extend(
                    (value, f"job {job['id']} animations[{animation_index}].frames[{frame_index}]")
                    for frame_index, value in enumerate(frames)
                )
            elif "source" in animation:
                source_values.append((animation["source"], f"job {job['id']} animations[{animation_index}].source"))
            else:
                raise ValueError(f"job {job['id']} animation {animation_index} requires frames or source")
    else:
        if spec.get("pack_type") != "ULTIMATE_SCREEN":
            raise ValueError(f"job {job['id']} ultimate spec pack_type must be ULTIMATE_SCREEN")
        _asset_id(spec.get("character_asset_key"), f"job {job['id']} character_asset_key")
        ultimate_id = _asset_id(spec.get("ultimate_id", "ultimate"), f"job {job['id']} ultimate_id")
        _asset_id(spec.get("screen_id", f"{ultimate_id}_background"), f"job {job['id']} screen_id")
        if "frames" in spec:
            frames = spec["frames"]
            if not isinstance(frames, list) or not frames:
                raise ValueError(f"job {job['id']} frames must be a non-empty array")
            source_values.extend((value, f"job {job['id']} frames[{index}]") for index, value in enumerate(frames))
        elif "source" in spec:
            source_values.append((spec["source"], f"job {job['id']} source"))
        else:
            raise ValueError(f"job {job['id']} ultimate spec requires frames or source")

    for value, label in source_values:
        _source_path(source_root, project_root, _path_from_source_spec(value, label), label)


def load_and_validate_manifest(manifest_path: Path, project_root: Path) -> dict[str, Any]:
    project_root = project_root.resolve()
    if not project_root.is_dir():
        raise ValueError(f"project root does not exist: {project_root}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in {manifest_path}: {exc}") from exc
    if not isinstance(manifest, dict):
        raise ValueError("art manifest root must be an object")
    unknown_top = set(manifest) - {"schema_version", "jobs"}
    if unknown_top:
        raise ValueError("unknown art manifest fields: " + ", ".join(sorted(unknown_top)))
    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise ValueError(f"schema_version must be {SCHEMA_VERSION}")
    jobs = manifest.get("jobs")
    if not isinstance(jobs, list) or not jobs:
        raise ValueError("jobs must be a non-empty array")

    validated_jobs: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for index, raw_job in enumerate(jobs):
        if not isinstance(raw_job, dict):
            raise ValueError(f"job {index} must be an object")
        job_type = raw_job.get("type")
        if job_type not in JOB_TYPES:
            raise ValueError(f"job {index} has unknown type: {job_type}")
        unknown = set(raw_job) - FIELDS_BY_TYPE[job_type]
        missing = REQUIRED_BY_TYPE[job_type] - set(raw_job)
        if unknown:
            raise ValueError(f"job {index} has unknown fields: {', '.join(sorted(unknown))}")
        if missing:
            raise ValueError(f"job {index} is missing fields: {', '.join(sorted(missing))}")
        job_id = raw_job.get("id")
        if not isinstance(job_id, str) or JOB_ID_RE.fullmatch(job_id) is None:
            raise ValueError(f"job {index} id must match {JOB_ID_RE.pattern}")
        if job_id in seen_ids:
            raise ValueError(f"duplicate job id: {job_id}")
        seen_ids.add(job_id)

        job = dict(raw_job)
        if job_type == "base_fighter":
            if job["character"] not in BASE_CHARACTERS:
                raise ValueError(f"job {job_id} unsupported base fighter: {job['character']}")
            source = _contained_path(project_root, job["source"], f"job {job_id} source", True)
            if not source.is_file():
                raise ValueError(f"job {job_id} source must be a file")
        else:
            spec_path = _contained_path(project_root, job["spec"], f"job {job_id} spec", True)
            if not spec_path.is_file():
                raise ValueError(f"job {job_id} spec must be a file")
            if "output_root" in job:
                _contained_output_path(project_root, job["output_root"], f"job {job_id} output_root")
            _validate_spec_sources(job, spec_path, project_root)
        validated_jobs.append(job)

    validated_jobs.sort(key=lambda item: item["id"])
    return {"schema_version": SCHEMA_VERSION, "jobs": validated_jobs}


def _optional_path(job: dict[str, Any], key: str, project_root: Path) -> Optional[Path]:
    if key not in job:
        return None
    if key == "output_root":
        return _contained_output_path(project_root, job[key], f"job {job['id']} {key}")
    return _contained_path(project_root, job[key], f"job {job['id']} {key}", True)


def execute_manifest(manifest: dict[str, Any], project_root: Path) -> list[dict[str, Any]]:
    scripts_dir = Path(__file__).resolve().parent
    if str(scripts_dir) not in sys.path:
        sys.path.insert(0, str(scripts_dir))
    from build_character_assets import build as build_base_fighter
    from build_effect_assets import build as build_effect
    from build_mode_character_assets import build as build_mode_fighter
    from build_ultimate_screen_assets import build as build_ultimate_screen

    builders = {
        "effect": build_effect,
        "mode_fighter": build_mode_fighter,
        "ultimate_screen": build_ultimate_screen,
    }
    results: list[dict[str, Any]] = []
    for job in manifest["jobs"]:
        if job["type"] == "base_fighter":
            result = build_base_fighter(
                job["character"],
                _contained_path(project_root, job["source"], f"job {job['id']} source", True),
                project_root,
            )
        else:
            result = builders[job["type"]](
                project_root,
                _contained_path(project_root, job["spec"], f"job {job['id']} spec", True),
                _optional_path(job, "source_root", project_root),
                _optional_path(job, "output_root", project_root),
            )
        results.append({"id": job["id"], "type": job["type"], "result": result})
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    try:
        project_root = args.project_root.resolve()
        manifest = load_and_validate_manifest(args.manifest.resolve(), project_root)
        if args.validate_only:
            print(f"ART MANIFEST PASS: {len(manifest['jobs'])} job(s), no outputs written")
            return 0
        results = execute_manifest(manifest, project_root)
    except (ImportError, OSError, RuntimeError, ValueError) as exc:
        print(f"ART MANIFEST FAIL: {exc}", file=sys.stderr)
        return 1
    for result in results:
        print(f"ART BUILD PASS: {result['id']} ({result['type']})")
    print(f"ART MANIFEST BUILD PASS: {len(results)} job(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
