#!/usr/bin/env python3
"""Prove four representative contributor branches merge without path overlap."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROLE_ORDER = ["art", "balance", "frontend", "skill"]


def simulation_plan(project_root: Path) -> dict[str, Any]:
    del project_root
    return {
        "target_character": "magic_orange_cat",
        "roles": {
            "art": {"path": "content/characters/magic_orange_cat/presentation/character_presentation.tres"},
            "balance": {"path": "content/characters/magic_orange_cat/gameplay/moves/stand_light.tres"},
            "frontend": {"path": "frontend/mode_select_scene.gd"},
            "skill": {"path": "content/characters/magic_orange_cat/gameplay/moves/magic_circle_l1.tres"},
        },
    }


def validate_plan(plan: dict[str, Any], project_root: Path) -> None:
    if not isinstance(plan, dict) or not isinstance(plan.get("target_character"), str) or not plan["target_character"]:
        raise ValueError("simulation target_character must be a non-empty stable ID")
    roles = plan.get("roles")
    if not isinstance(roles, dict) or set(roles) != set(ROLE_ORDER):
        raise ValueError("simulation roles must be exactly art, balance, frontend, and skill")
    seen: set[str] = set()
    for role in ROLE_ORDER:
        value = roles[role]
        if not isinstance(value, dict) or set(value) != {"path"}:
            raise ValueError(f"simulation role {role} must contain only path")
        relative = value["path"]
        if not isinstance(relative, str) or not relative:
            raise ValueError(f"simulation role {role} path must be non-empty")
        path = (project_root / relative).resolve()
        try:
            path.relative_to(project_root.resolve())
        except ValueError as exc:
            raise ValueError(f"simulation role {role} path escapes repository") from exc
        if relative in seen:
            raise ValueError(f"simulation path overlap: {relative}")
        seen.add(relative)
        if not path.is_file():
            raise ValueError(f"simulation representative path is missing: {relative}")


def _git(root: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=root,
        check=True,
        text=True,
        capture_output=True,
    )
    return result.stdout.strip()


def run_simulation(project_root: Path) -> dict[str, Any]:
    if shutil.which("git") is None:
        raise RuntimeError("git executable is unavailable")
    project_root = project_root.resolve()
    plan = simulation_plan(project_root)
    validate_plan(plan, project_root)
    roles = plan["roles"]

    with tempfile.TemporaryDirectory(prefix="meme-fighter-a-col-007-") as directory:
        sandbox = Path(directory)
        _git(sandbox, "init", "--initial-branch=main")
        _git(sandbox, "config", "user.name", "Meme Fighter Merge Simulation")
        _git(sandbox, "config", "user.email", "merge-simulation@example.invalid")
        for role in ROLE_ORDER:
            relative = Path(roles[role]["path"])
            destination = sandbox / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(project_root / relative, destination)
        _git(sandbox, "add", "--all")
        _git(sandbox, "commit", "-m", "simulation base")

        changed_by_role: dict[str, list[str]] = {}
        for role in ROLE_ORDER:
            branch = f"role/{role}"
            relative = roles[role]["path"]
            _git(sandbox, "switch", "-c", branch, "main")
            with (sandbox / relative).open("a", encoding="utf-8") as handle:
                handle.write(f"\n# A-COL-007 simulation: role={role} target={plan['target_character']}\n")
            _git(sandbox, "add", "--", relative)
            _git(sandbox, "commit", "-m", f"simulate {role} contribution")
            changed = _git(sandbox, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").splitlines()
            if changed != [relative]:
                raise RuntimeError(f"{role} branch changed unexpected paths: {changed}")
            changed_by_role[role] = changed
            _git(sandbox, "switch", "main")

        all_paths = [path for paths in changed_by_role.values() for path in paths]
        if len(all_paths) != len(set(all_paths)):
            raise RuntimeError("role branches overlap on at least one path")

        _git(sandbox, "switch", "-c", "integration", "main")
        for role in ROLE_ORDER:
            _git(sandbox, "merge", "--no-ff", "--no-edit", f"role/{role}")
            _git(sandbox, "merge-base", "--is-ancestor", f"role/{role}", "integration")
        final_paths = _git(sandbox, "diff", "--name-only", "main..integration").splitlines()
        if sorted(final_paths) != sorted(all_paths):
            raise RuntimeError(f"integration changed-path mismatch: {final_paths}")
        if _git(sandbox, "status", "--porcelain"):
            raise RuntimeError("integration worktree is not clean")

    return {
        "status": "PASS",
        "target_character": plan["target_character"],
        "merged_roles": ROLE_ORDER,
        "paths": {role: roles[role]["path"] for role in ROLE_ORDER},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        report = run_simulation(args.project_root)
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as exc:
        detail = exc.stderr.strip() if isinstance(exc, subprocess.CalledProcessError) else str(exc)
        print(f"MERGE SIMULATION FAIL: {detail}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(f"MERGE SIMULATION PASS: target={report['target_character']}")
        for role in report["merged_roles"]:
            print(f"  {role}: {report['paths'][role]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
