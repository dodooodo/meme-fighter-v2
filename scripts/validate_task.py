#!/usr/bin/env python3
"""Validate a Dorian task packet and its declared git-diff scope."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REQUIRED = {
    "id", "stage", "type", "status", "dependencies", "allowed_paths",
    "forbidden_paths", "required_specs", "required_checks",
}
STATUSES = {"draft", "blocked", "ready", "in_progress", "done"}
DEPENDENCY_GATED_STATUSES = {"ready", "in_progress", "done"}
TASK_BRANCH_RE = re.compile(
    r"^task/(?P<id>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)(?:-(?P<slug>[a-z][a-z0-9-]*))?$"
)


def parse_value(value: str) -> str | list[str]:
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        body = value[1:-1].strip()
        return [] if not body else [item.strip().strip('"\'') for item in body.split(",")]
    return value.strip('"\'')


def parse_packet(path: Path) -> dict[str, str | list[str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise ValueError("frontmatter must start with ---")
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise ValueError("frontmatter closing --- is missing") from exc
    result: dict[str, str | list[str]] = {}
    for line in lines[1:end]:
        if not line or line.lstrip().startswith("#"):
            continue
        match = re.fullmatch(r"([a-z_]+):\s*(.+)", line)
        if not match:
            raise ValueError(f"unsupported frontmatter line: {line}")
        key, value = match.groups()
        if key in result:
            raise ValueError(f"duplicate frontmatter key: {key}")
        result[key] = parse_value(value)
    missing = REQUIRED - result.keys()
    if missing:
        raise ValueError("missing required keys: " + ", ".join(sorted(missing)))
    if result["status"] not in STATUSES:
        raise ValueError("invalid status")
    for key in REQUIRED - {"id", "stage", "type", "status"}:
        if not isinstance(result[key], list):
            raise ValueError(f"{key} must be a bracketed list")
    return result


def task_path_from_branch(branch: str, root: Path) -> Path:
    match = TASK_BRANCH_RE.fullmatch(branch)
    if not match:
        raise ValueError("branch must match task/<TASK-ID>-<lowercase-slug>")
    task_id = match.group("id")
    active = root / "docs" / "tasks" / "active" / f"{task_id}.md"
    completed = root / "docs" / "tasks" / "completed" / f"{task_id}.md"
    matches = [path for path in (active, completed) if path.is_file()]
    if len(matches) != 1:
        raise ValueError(f"branch task {task_id} must resolve to exactly one packet")
    return matches[0]


def _run_git(arguments: list[str], root: Path) -> str:
    result = subprocess.run(
        ["git", *arguments], cwd=root, check=True, text=True, capture_output=True
    )
    return result.stdout.strip()


def resolve_base(root: Path) -> str:
    for candidate in ("origin/main", "main"):
        try:
            base = _run_git(["merge-base", candidate, "HEAD"], root)
        except subprocess.CalledProcessError:
            continue
        if base:
            return base
    raise ValueError("cannot resolve merge-base against origin/main or main")


def git_paths(base: str, root: Path) -> list[str]:
    diff = _run_git(["diff", "--name-only", base, "--"], root)
    status = _run_git(["status", "--porcelain"], root)
    paths = {line.strip() for line in diff.splitlines() if line.strip()}
    for line in status.splitlines():
        if len(line) >= 4 and line[:2] == "??":
            paths.add(line[3:])
    return sorted(paths)


def _dependency_packet(dependency: str, root: Path) -> Path:
    active = root / "docs" / "tasks" / "active" / f"{dependency}.md"
    completed = root / "docs" / "tasks" / "completed" / f"{dependency}.md"
    matches = [path for path in (active, completed) if path.is_file()]
    if len(matches) != 1:
        raise ValueError(f"dependency {dependency} must resolve to exactly one packet")
    return matches[0]


def validate_metadata(
    packet: dict[str, str | list[str]], task_path: Path, root: Path
) -> None:
    task_id = str(packet["id"])
    if task_path.stem != task_id:
        raise ValueError(f"packet filename {task_path.stem} does not match id {task_id}")
    dependencies = packet["dependencies"]
    assert isinstance(dependencies, list)
    if task_id in dependencies:
        raise ValueError("task cannot depend on itself")
    unfinished = []
    for dependency in dependencies:
        dependency_path = _dependency_packet(dependency, root)
        dependency_packet = parse_packet(dependency_path)
        if dependency_packet["id"] != dependency:
            raise ValueError(f"dependency filename/id mismatch: {dependency}")
        if dependency_packet["status"] != "done":
            unfinished.append(f"{dependency}={dependency_packet['status']}")
    if packet["status"] in DEPENDENCY_GATED_STATUSES and unfinished:
        raise ValueError("unfinished dependencies: " + ", ".join(unfinished))
    required_specs = packet["required_specs"]
    assert isinstance(required_specs, list)
    missing_specs = [spec for spec in required_specs if not (root / spec).exists()]
    if missing_specs:
        raise ValueError("missing required specs: " + ", ".join(missing_specs))
    required_checks = packet["required_checks"]
    assert isinstance(required_checks, list)
    if not required_checks or any(not check.strip() for check in required_checks):
        raise ValueError("required_checks must contain commands")


def matches(path: str, rule: str) -> bool:
    rule = rule.rstrip("/")
    return path == rule or path.startswith(rule + "/")


def main() -> int:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--task", help="Repository-relative task packet")
    source.add_argument("--branch", help="Task branch: task/<TASK-ID>-<lowercase-slug>")
    parser.add_argument("--base", help="Git revision; defaults to main merge-base")
    parser.add_argument("--no-diff", action="store_true", help="Validate metadata only")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        task_path = (
            task_path_from_branch(args.branch, root)
            if args.branch
            else (root / args.task).resolve()
        )
        if not task_path.is_file() or root not in task_path.parents:
            raise ValueError(f"missing or out-of-repository packet: {task_path}")
        packet = parse_packet(task_path)
        validate_metadata(packet, task_path, root)
        if args.no_diff:
            print(f"TASK VALIDATION PASS: {packet['id']} metadata")
            return 0
        base = args.base or resolve_base(root)
        changed = git_paths(base, root)
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        detail = exc.stderr.strip() if isinstance(exc, subprocess.CalledProcessError) else str(exc)
        print(f"TASK VALIDATION FAIL: {detail}", file=sys.stderr)
        return 2
    if not changed:
        print("TASK VALIDATION FAIL: no changed paths resolved", file=sys.stderr)
        return 1
    allowed = packet["allowed_paths"]
    forbidden = packet["forbidden_paths"]
    assert isinstance(allowed, list) and isinstance(forbidden, list)
    task_relative = str(task_path.relative_to(root))
    violations = []
    for path in changed:
        if path == task_relative:
            continue
        if any(matches(path, rule) for rule in forbidden):
            violations.append(f"forbidden: {path}")
        elif not any(matches(path, rule) for rule in allowed):
            violations.append(f"outside allowed_paths: {path}")
    if violations:
        print("TASK VALIDATION FAIL: " + str(packet["id"]), file=sys.stderr)
        print("\n".join(violations), file=sys.stderr)
        return 1
    print(
        f"TASK VALIDATION PASS: {packet['id']} "
        f"({len(changed)} changed paths from {base})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
