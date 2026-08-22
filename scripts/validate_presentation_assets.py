#!/usr/bin/env python3
"""Validate deterministic production character presentation assets.

Presentation-only validator. It never mutates gameplay resources.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops

# Reuse the exact deterministic RGB edge-connected cleanup routine used by the builder.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_character_assets import remove_edge_connected_background  # noqa: E402

EXPECTED_COUNTS = {
    "idle": 12, "crouch": 6, "landing": 7, "walk_forward": 12, "walk_back": 13,
    "jump": 11, "air_attack": 14, "guard_stand": 6, "guard_crouch": 6,
    "blockstun": 6, "hitstun": 7, "thrown": 8, "knockdown": 9, "getup": 8,
    "ko": 12, "dash_forward": 7, "backstep": 6, "stand_light": 10,
    "stand_heavy": 15, "crouch_low": 11, "ground_throw": 14,
    "special_neutral": 25, "ultimate": 25,
}
EXPECTED_KEYS = list(EXPECTED_COUNTS)
LOOP_TRUE = {"idle", "walk_forward", "walk_back", "crouch", "guard_stand", "guard_crouch"}
ATTACK_KEYS = {"stand_light", "stand_heavy", "crouch_low", "air_attack", "ground_throw", "special_neutral", "ultimate"}
EXPECTED_IDS = {"salad_cat": "generic_fighter", "magic_orange_cat": "zone_fighter"}
EXPECTED_NAMES = {"salad_cat": "Salad Cat", "magic_orange_cat": "Magic Orange Cat"}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def from_res(project_root: Path, res_path: str) -> Path:
    if not isinstance(res_path, str) or not res_path.startswith("res://"):
        raise ValueError(f"not a res:// path: {res_path!r}")
    return project_root / res_path[len("res://"):]


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def crop_with_builder_cleanup(source: Image.Image, safe_rect: list[int]) -> Image.Image:
    cell = source.crop(tuple(map(int, safe_rect)))
    if "A" in cell.getbands():
        return cell.convert("RGBA")
    cleaned, _meta = remove_edge_connected_background(cell)
    return cleaned


def check_binding(project_root: Path, asset_key: str, errors: list[str]) -> None:
    if asset_key == "salad_cat":
        resource = project_root / "presentation/characters/generic_fighter_presentation.tres"
        expected_scene = "res://presentation/visuals/production/salad_cat_visual.tscn"
        expected_display = 'display_name = "Salad Cat"'
    else:
        resource = project_root / "presentation/characters/zone_fighter_presentation.tres"
        expected_scene = "res://presentation/visuals/production/magic_orange_cat_visual.tscn"
        expected_display = 'display_name = "Magic Orange Cat"'
    if not resource.is_file():
        errors.append(f"missing presentation binding resource: {resource}")
        return
    body = resource.read_text(encoding="utf-8")
    if expected_scene not in body:
        errors.append(f"presentation binding does not resolve {asset_key} production visual")
    if expected_display not in body:
        errors.append(f"presentation display name mismatch for {asset_key}")
    for key in ("special_neutral", "ultimate"):
        if f'animation_key = &"{key}"' not in body:
            errors.append(f"presentation binding missing canonical animation key {key}")


def validate_character(project_root: Path, asset_key: str) -> tuple[list[str], list[str], dict]:
    errors: list[str] = []
    warnings: list[str] = []
    manifest_path = project_root / "assets/characters" / asset_key / "animations/manifest.json"
    if not manifest_path.is_file():
        return [f"missing manifest: {manifest_path}"], warnings, {}
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    if int(manifest.get("manifest_version", 0)) != 3:
        errors.append("BASE_FIGHTER manifest_version must be 3")
    if manifest.get("pack_type") != "BASE_FIGHTER":
        errors.append("base character manifest pack_type must be BASE_FIGHTER")
    if str(manifest.get("mode_id", "")) != "":
        errors.append("BASE_FIGHTER mode_id must be empty")
    if manifest.get("crop_algorithm") != "GRID/GUTTER DETECTION":
        errors.append("crop_algorithm must be GRID/GUTTER DETECTION")
    if manifest.get("naive_width_division") not in (False, "REMOVED"):
        errors.append("naive width/5 slicing must be removed")
    if manifest.get("sheet_count") != 10:
        errors.append("sheet_count must be 10")
    if manifest.get("grid_columns") != 5 or manifest.get("grid_rows") != 5:
        errors.append("grid must be 5x5")
    if manifest.get("frame_count") != 250:
        errors.append("frame_count must be 250")
    if manifest.get("character_id") != EXPECTED_IDS[asset_key]:
        errors.append(f"{asset_key} character_id must be {EXPECTED_IDS[asset_key]}")
    if manifest.get("display_name") != EXPECTED_NAMES[asset_key]:
        errors.append(f"{asset_key} display name mismatch")
    if asset_key == "magic_orange_cat" and "BOUND" not in str(manifest.get("gameplay_slot", "")):
        errors.append("Magic Orange Cat must be BOUND to zone_fighter")

    # Builder source-level policy guard: no executable rational/average slicing implementation.
    builder_body = (project_root / "scripts/build_character_assets.py").read_text(encoding="utf-8")
    prohibited_exec = ["def rational_edges", "154/153/154/153/154"]
    for token in prohibited_exec:
        if token in builder_body:
            errors.append(f"prohibited naïve/rational slicing implementation remains: {token}")

    bundle_path = from_res(project_root, str(manifest.get("source_bundle_path", "")))
    if not bundle_path.is_file():
        errors.append("missing packaged source ZIP")
    elif sha256_file(bundle_path) != manifest.get("source_sha256"):
        errors.append("packaged source ZIP SHA mismatch")

    sheets = manifest.get("source_sheets", [])
    if not isinstance(sheets, list) or len(sheets) != 10:
        errors.append(f"expected 10 source sheets, got {len(sheets) if isinstance(sheets, list) else 'invalid'}")
        sheets = []
    source_images: dict[int, Image.Image] = {}
    source_modes: dict[int, str] = {}
    source_max_w = source_max_h = 0
    for sheet in sheets:
        try:
            number = int(sheet["sheet"])
            path = from_res(project_root, sheet["path"])
            if not path.is_file():
                errors.append(f"missing source sheet {number:02d}")
                continue
            if sha256_file(path) != sheet.get("sha256"):
                errors.append(f"source sheet SHA mismatch: {number:02d}")
            opened = Image.open(path)
            source_max_w = max(source_max_w, opened.width)
            source_max_h = max(source_max_h, opened.height)
            source_modes[number] = opened.mode
            source_images[number] = opened.copy()
            grid = sheet.get("grid_detection", {})
            if grid.get("algorithm") != "GRID/GUTTER DETECTION":
                errors.append(f"sheet {number:02d}: missing grid/gutter detector metadata")
            if len(grid.get("row_x_edges", [])) != 5 or len(grid.get("column_y_edges", [])) != 5:
                errors.append(f"sheet {number:02d}: localized grid edges missing")
        except Exception as exc:
            errors.append(f"unreadable source sheet metadata: {exc}")

    animations = manifest.get("animations", [])
    if not isinstance(animations, list):
        animations = []
    by_key = {str(item.get("key")): item for item in animations if isinstance(item, dict)}
    if len(animations) != 23 or set(by_key) != set(EXPECTED_KEYS):
        errors.append("all 23 canonical animation keys must exist exactly once")

    seen_paths: set[str] = set()
    output_count = 0
    failed_cells = 0
    frames_touching_canvas = 0
    suspected_neighbor_contamination = int(manifest.get("separator_contamination_candidates", 0) or 0)
    source_missing: list[int] = []
    max_w = max_h = 0
    decoded_bytes = 0
    safe_boundary_touch_frames: list[int] = []

    for key, expected_count in EXPECTED_COUNTS.items():
        anim = by_key.get(key)
        if anim is None:
            continue
        frames = anim.get("frames", [])
        if len(frames) != expected_count or int(anim.get("frame_count", -1)) != expected_count:
            errors.append(f"{key}: expected {expected_count} frames, got {len(frames)}")
        if key in LOOP_TRUE and anim.get("loop") is not True:
            errors.append(f"{key}: must loop/hold")
        if key in ATTACK_KEYS and anim.get("loop") is not False:
            errors.append(f"{key}: attack animation must not loop")
        if key == "ko" and (anim.get("loop") is not False or anim.get("hold_final_frame") is not True):
            errors.append("KO must be non-loop and hold final frame")
        if key in ATTACK_KEYS and anim.get("playback_authority") != "MOVE_PHASE_TIMELINE":
            errors.append(f"{key}: must use MOVE_PHASE_TIMELINE presentation authority")
        if key == "special_neutral":
            policy = anim.get("timeline_policy", {})
            if int(policy.get("startup_hold_ticks", 0)) < 2 or int(policy.get("contact_hold_ticks", 0)) < 2:
                errors.append("special_neutral: missing anticipation/contact presentation holds")
        if key == "ultimate":
            policy = anim.get("timeline_policy", {})
            if int(policy.get("startup_hold_ticks", 0)) < 4 or int(policy.get("contact_hold_ticks", 0)) < 3:
                errors.append("ultimate: missing strong anticipation/contact presentation holds")

        for frame in frames:
            output_count += 1
            global_frame = int(frame.get("global_frame", -1))
            res_path = str(frame.get("path", ""))
            if res_path in seen_paths:
                errors.append(f"duplicate runtime output: {res_path}")
            seen_paths.add(res_path)
            runtime_path = from_res(project_root, res_path)
            if not runtime_path.is_file():
                errors.append(f"missing runtime frame: {res_path}")
                failed_cells += 1
                continue
            if sha256_file(runtime_path) != frame.get("output_sha256"):
                errors.append(f"runtime SHA mismatch: {res_path}")
                failed_cells += 1
            try:
                opened = Image.open(runtime_path)
                if opened.mode != "RGBA":
                    errors.append(f"runtime frame must decode as RGBA: {res_path} mode={opened.mode}")
                runtime = opened.convert("RGBA")
            except Exception as exc:
                errors.append(f"unreadable runtime frame {res_path}: {exc}")
                failed_cells += 1
                continue
            if runtime.width <= 0 or runtime.height <= 0:
                errors.append(f"zero-size runtime frame: {res_path}")
                failed_cells += 1
                continue
            max_w = max(max_w, runtime.width)
            max_h = max(max_h, runtime.height)
            decoded_bytes += runtime.width * runtime.height * 4
            expected_size = tuple(int(v) for v in frame.get("runtime_size", []))
            if runtime.size != expected_size:
                errors.append(f"runtime size mismatch: {res_path}")
                failed_cells += 1

            bbox = alpha_bbox(runtime)
            if frame.get("source_foreground_missing"):
                source_missing.append(global_frame)
                if bbox is not None:
                    errors.append(f"source-missing frame unexpectedly fabricated pixels: {res_path}")
                errors.append(f"source cell contains no valid frame foreground: global frame {global_frame:03d}")
                failed_cells += 1
                continue
            if bbox is None:
                errors.append(f"runtime frame is empty: {res_path}")
                failed_cells += 1
                continue

            l, t, r, b = bbox
            margins = (l, runtime.width - r, t, runtime.height - b)
            if min(margins) <= 0 or frame.get("touches_runtime_canvas"):
                frames_touching_canvas += 1
                errors.append(f"foreground touches runtime canvas: {res_path}")
                failed_cells += 1
            if frame.get("foreground_touches_safe_boundary"):
                safe_boundary_touch_frames.append(global_frame)
                warnings.append(f"frame {global_frame:03d} meaningful foreground reaches detected safe-cell boundary; inspect QA overlay")

            # Final crop must remain fully inside its non-overlapping detected safe cell.
            safe = [int(v) for v in frame.get("safe_cell_rect", [])]
            crop = [int(v) for v in frame.get("final_crop_rect_source", [])]
            if len(safe) != 4 or len(crop) != 4 or not (safe[0] <= crop[0] < crop[2] <= safe[2] and safe[1] <= crop[1] < crop[3] <= safe[3]):
                errors.append(f"final crop escapes safe cell: {res_path}")
                failed_cells += 1
                continue

            # Pixel preservation: compare source-derived crop to the exact pasted runtime rectangle.
            sheet_number = int(frame.get("sheet", 0))
            source = source_images.get(sheet_number)
            if source is None:
                continue
            cell = crop_with_builder_cleanup(source, safe)
            local_crop = (crop[0] - safe[0], crop[1] - safe[1], crop[2] - safe[0], crop[3] - safe[1])
            expected_crop = cell.crop(local_crop).convert("RGBA")
            paste = [int(v) for v in frame.get("runtime_paste", [])]
            if len(paste) != 2:
                errors.append(f"runtime_paste metadata invalid: {res_path}")
                failed_cells += 1
                continue
            actual_crop = runtime.crop((paste[0], paste[1], paste[0] + expected_crop.width, paste[1] + expected_crop.height))
            if actual_crop.size != expected_crop.size or ImageChops.difference(expected_crop, actual_crop).getbbox() is not None:
                errors.append(f"runtime pixels do not match deterministic source crop: {res_path}")
                failed_cells += 1

            pivot = frame.get("pivot_pixels", [])
            if len(pivot) != 2 or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in pivot):
                errors.append(f"invalid feet-center pivot: {res_path}")

    if output_count != 250:
        errors.append(f"runtime output count must be 250, got {output_count}")
    manifest_missing = sorted(int(v) for v in manifest.get("source_missing_foreground_frames", []))
    if sorted(source_missing) != manifest_missing:
        errors.append("source-missing frame manifest mismatch")

    walk_validation = manifest.get("walk_ground_validation", {})
    walk_pass = True
    for walk_key in ("walk_forward", "walk_back"):
        result = walk_validation.get(walk_key, {})
        if result.get("status") != "PASS":
            walk_pass = False
            errors.append(f"{walk_key} feet baseline validation failed: {result}")
        elif float(result.get("max_deviation", 999)) > 2.0:
            walk_pass = False
            errors.append(f"{walk_key} feet baseline deviation exceeds 2px")

    sprite_frames = from_res(project_root, str(manifest.get("sprite_frames_resource", "")))
    visual_scene = from_res(project_root, str(manifest.get("visual_scene", "")))
    if not sprite_frames.is_file():
        errors.append("missing SpriteFrames resource")
    if not visual_scene.is_file():
        errors.append("missing FighterVisual scene")
    check_binding(project_root, asset_key, errors)

    # Magic is a required live Battle mapping in this pass.
    if asset_key == "magic_orange_cat":
        battle = (project_root / "battle/battle_scene.tscn").read_text(encoding="utf-8")
        if 'character_b_data = ExtResource("7_zone")' not in battle or 'character_b_presentation = ExtResource("10_zone_present")' not in battle:
            errors.append("Default Battle does not resolve P2 zone_fighter -> Magic Orange Cat")

    stats = {
        "asset_key": asset_key,
        "source_sheets": len(sheets),
        "frames": output_count,
        "animations": len(animations),
        "failed_cells": failed_cells,
        "crop_algorithm": manifest.get("crop_algorithm"),
        "naive_width_division": manifest.get("naive_width_division"),
        "crop_overrides": int(manifest.get("crop_overrides_applied", 0) or 0),
        "frames_touching_canvas": frames_touching_canvas,
        "frames_touching_safe_cell_boundary": len(safe_boundary_touch_frames),
        "suspected_neighbor_contamination": suspected_neighbor_contamination,
        "source_missing_foreground_frames": source_missing,
        "walk_feet_baseline_validation": "PASS" if walk_pass else "FAIL",
        "max_frame_dimensions": f"{max_w}x{max_h}",
        "estimated_decoded_rgba_memory_bytes": decoded_bytes,
        "estimated_decoded_rgba_memory_mib": round(decoded_bytes / (1024 * 1024), 3),
        "source_sha256": manifest.get("source_sha256"),
        "source_max_dimensions": f"{source_max_w}x{source_max_h}",
    }
    return errors, warnings, stats



def validate_pack_manifest(project_root: Path, manifest_path: Path) -> tuple[list[str], list[str], dict]:
    """Validate a non-base M9P pack without imposing square/250-frame assumptions."""
    errors: list[str] = []
    warnings: list[str] = []
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [f"invalid manifest JSON: {exc}"], warnings, {}
    pack_type = str(manifest.get("pack_type", ""))
    if pack_type == "BASE_FIGHTER":
        asset_key = str(manifest.get("character_asset_key", ""))
        if asset_key in EXPECTED_IDS:
            return validate_character(project_root, asset_key)
        return [f"unsupported BASE_FIGHTER asset key: {asset_key}"], warnings, {}
    if int(manifest.get("manifest_version", 0)) != 3:
        errors.append("manifest_version must be 3")
    if pack_type not in {"MODE_FIGHTER", "PROJECTILE", "WORLD_EFFECT", "HAZARD", "ATTACHMENT", "ULTIMATE_SCREEN"}:
        errors.append(f"unknown pack_type: {pack_type}")
        return errors, warnings, {"manifest": manifest_path.as_posix(), "pack_type": pack_type}

    frame_items: list[dict] = []
    if pack_type == "MODE_FIGHTER":
        mode_id = str(manifest.get("mode_id", ""))
        if not mode_id:
            errors.append("MODE_FIGHTER mode_id is required")
        if manifest.get("square_canvas_required") is not False:
            errors.append("MODE_FIGHTER must not require a square canvas")
        if manifest.get("resize_body") is not False:
            errors.append("MODE_FIGHTER builder must preserve body scale")
        animations = manifest.get("animations", [])
        if not isinstance(animations, list) or not animations:
            errors.append("MODE_FIGHTER animations must be non-empty")
            animations = []
        keys = {str(anim.get("key", "")) for anim in animations if isinstance(anim, dict)}
        for required in manifest.get("required_animations", []):
            if str(required) not in keys:
                errors.append(f"MODE_FIGHTER missing required animation: {required}")
        for anim in animations:
            if isinstance(anim, dict):
                frames = anim.get("frames", [])
                if int(anim.get("frame_count", -1)) != len(frames):
                    errors.append(f"MODE_FIGHTER {anim.get('key')}: frame_count mismatch")
                frame_items.extend(frame for frame in frames if isinstance(frame, dict))
        # Deliberately no 250-frame check and no width==height check.
        if int(manifest.get("frame_count", -1)) != len(frame_items):
            errors.append("MODE_FIGHTER total frame_count mismatch")
    elif pack_type == "ULTIMATE_SCREEN":
        frame_items = [frame for frame in manifest.get("frames", []) if isinstance(frame, dict)]
        if manifest.get("runtime_size") != [1280, 720]:
            errors.append("ULTIMATE_SCREEN runtime_size must be 1280x720")
        if manifest.get("aspect_ratio") != "16:9":
            errors.append("ULTIMATE_SCREEN aspect_ratio must be 16:9")
        if int(manifest.get("frame_count", -1)) != len(frame_items):
            errors.append("ULTIMATE_SCREEN frame_count mismatch")
    else:
        frame_items = [frame for frame in manifest.get("frames", []) if isinstance(frame, dict)]
        if manifest.get("square_canvas_required") is not False:
            errors.append(f"{pack_type} must allow arbitrary aspect ratio")
        if manifest.get("aspect_ratio_restriction") != "NONE":
            errors.append(f"{pack_type} aspect_ratio_restriction must be NONE")
        if int(manifest.get("frame_count", -1)) != len(frame_items):
            errors.append(f"{pack_type} frame_count mismatch")

    rectangular_frames = 0
    max_w = max_h = 0
    for frame in frame_items:
        path_value = str(frame.get("path", ""))
        try:
            path = from_res(project_root, path_value)
        except Exception:
            errors.append(f"invalid frame path: {path_value}")
            continue
        if not path.is_file():
            errors.append(f"missing frame: {path_value}")
            continue
        try:
            opened = Image.open(path)
        except Exception as exc:
            errors.append(f"unreadable frame {path_value}: {exc}")
            continue
        max_w, max_h = max(max_w, opened.width), max(max_h, opened.height)
        if opened.width != opened.height:
            rectangular_frames += 1
        size_meta = frame.get("runtime_size", [])
        if size_meta and [opened.width, opened.height] != [int(v) for v in size_meta]:
            errors.append(f"runtime_size mismatch: {path_value}")
        if pack_type != "ULTIMATE_SCREEN":
            if opened.mode != "RGBA":
                errors.append(f"{pack_type} frame must preserve RGBA: {path_value} mode={opened.mode}")
            rgba = opened.convert("RGBA")
            bbox = alpha_bbox(rgba)
            if bbox is None:
                errors.append(f"empty frame: {path_value}")
                continue
            pivot = frame.get("pivot_pixels", [])
            if len(pivot) != 2 or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in pivot):
                errors.append(f"invalid pivot: {path_value}")
            elif not (0 <= float(pivot[0]) <= opened.width and 0 <= float(pivot[1]) <= opened.height):
                errors.append(f"pivot outside frame: {path_value}")
            if pack_type == "MODE_FIGHTER":
                if bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= opened.width or bbox[3] >= opened.height:
                    errors.append(f"MODE_FIGHTER foreground touches texture border: {path_value}")
                # Feet-center contract: pivot should stay close to lowest opaque body support.
                if len(pivot) == 2 and abs(float(pivot[1]) - float(bbox[3] - 1)) > 8.0:
                    warnings.append(f"MODE_FIGHTER pivot is >8px above/below lowest alpha support: {path_value}")
        else:
            if [opened.width, opened.height] != [1280, 720]:
                errors.append(f"ULTIMATE_SCREEN frame is not 1280x720: {path_value}")

    stats = {
        "manifest": manifest_path.resolve().relative_to(project_root.resolve()).as_posix() if manifest_path.resolve().is_relative_to(project_root.resolve()) else manifest_path.as_posix(),
        "pack_type": pack_type,
        "frame_count": len(frame_items),
        "rectangular_frames": rectangular_frames,
        "max_frame_dimensions": f"{max_w}x{max_h}",
    }
    return errors, warnings, stats


def discover_pack_manifests(project_root: Path) -> list[Path]:
    manifests: list[Path] = []
    root = project_root / "assets/characters"
    if root.is_dir():
        for path in root.rglob("manifest.json"):
            manifests.append(path)
    return sorted(set(manifests))

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--character", action="append", choices=["salad_cat", "magic_orange_cat"])
    parser.add_argument("--manifest", action="append", type=Path)
    parser.add_argument("--all-packs", action="store_true")
    args = parser.parse_args()
    root = args.project_root.resolve()

    requests: list[tuple[str, object]] = []
    if args.character:
        requests.extend(("base", name) for name in args.character)
    elif not args.manifest and not args.all_packs:
        requests.extend(("base", name) for name in ["salad_cat", "magic_orange_cat"])
    if args.manifest:
        requests.extend(("manifest", path.resolve()) for path in args.manifest)
    if args.all_packs:
        requests.extend(("manifest", path.resolve()) for path in discover_pack_manifests(root))

    seen: set[str] = set()
    total_errors = 0
    for kind, value in requests:
        key = f"{kind}:{value}"
        if key in seen:
            continue
        seen.add(key)
        if kind == "base":
            errors, warnings, stats = validate_character(root, str(value))
            label = str(value)
        else:
            manifest_path = value if isinstance(value, Path) else Path(str(value))
            errors, warnings, stats = validate_pack_manifest(root, manifest_path)
            label = manifest_path.as_posix()
        print(f"[{label}]")
        for warning in warnings:
            print(f"WARNING: {warning}")
        for error in errors:
            print(f"ERROR: {error}")
        for stat_key, stat_value in stats.items():
            print(f"{stat_key}={stat_value}")
        print(f"validation={'PASS' if not errors else 'FAIL'}")
        print()
        total_errors += len(errors)
    print(f"total_errors={total_errors}")
    return 0 if total_errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
