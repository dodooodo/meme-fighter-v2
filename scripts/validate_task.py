#!/usr/bin/env python3
"""Validate a Dorian task packet and its declared git-diff scope.

This intentionally accepts only the compact frontmatter subset documented in
docs/tasks/TASK_TEMPLATE.md, avoiding a runtime YAML dependency.
"""
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


def git_paths(base: str) -> list[str]:
    diff = subprocess.run(["git", "diff", "--name-only", base], check=True, text=True, capture_output=True)
    status = subprocess.run(["git", "status", "--porcelain"], check=True, text=True, capture_output=True)
    paths = set(line.strip() for line in diff.stdout.splitlines() if line.strip())
    for line in status.stdout.splitlines():
        if len(line) >= 4 and line[:2] == "??":
            paths.add(line[3:])
    return sorted(paths)


def matches(path: str, rule: str) -> bool:
    rule = rule.rstrip("/")
    return path == rule or path.startswith(rule + "/")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--task", required=True, help="Repository-relative task packet")
    parser.add_argument("--base", default="HEAD", help="Git revision for changed paths")
    parser.add_argument("--no-diff", action="store_true", help="Validate frontmatter only")
    args = parser.parse_args()
    task_path = Path(args.task)
    if not task_path.is_file():
        print(f"TASK VALIDATION FAIL: missing packet: {task_path}", file=sys.stderr)
        return 2
    try:
        packet = parse_packet(task_path)
    except (OSError, ValueError) as exc:
        print(f"TASK VALIDATION FAIL: {exc}", file=sys.stderr)
        return 2
    dependencies = packet["dependencies"]
    assert isinstance(dependencies, list)
    missing_dependencies = [dep for dep in dependencies if not Path(f"docs/tasks/active/{dep}.md").is_file() and not Path(f"docs/tasks/completed/{dep}.md").is_file()]
    if missing_dependencies:
        print("TASK VALIDATION FAIL: missing dependency packets: " + ", ".join(missing_dependencies), file=sys.stderr)
        return 2
    required_specs = packet["required_specs"]
    assert isinstance(required_specs, list)
    missing_specs = [spec for spec in required_specs if not Path(spec).exists()]
    if missing_specs:
        print("TASK VALIDATION FAIL: missing required specs: " + ", ".join(missing_specs), file=sys.stderr)
        return 2
    required_checks = packet["required_checks"]
    assert isinstance(required_checks, list)
    if not required_checks or any(not check.strip() for check in required_checks):
        print("TASK VALIDATION FAIL: required_checks must contain commands", file=sys.stderr)
        return 2
    if args.no_diff:
        print(f"TASK VALIDATION PASS: {packet['id']} frontmatter")
        return 0
    try:
        changed = git_paths(args.base)
    except subprocess.CalledProcessError as exc:
        print(f"TASK VALIDATION FAIL: git diff failed: {exc.stderr.strip()}", file=sys.stderr)
        return 2
    allowed = packet["allowed_paths"]
    forbidden = packet["forbidden_paths"]
    assert isinstance(allowed, list) and isinstance(forbidden, list)
    violations = []
    for path in changed:
        if matches(path, "docs/tasks") or path == "scripts/validate_task.py":
            continue  # workflow metadata/tool may accompany every task
        if any(matches(path, rule) for rule in forbidden):
            violations.append(f"forbidden: {path}")
        elif not any(matches(path, rule) for rule in allowed):
            violations.append(f"outside allowed_paths: {path}")
    if violations:
        print("TASK VALIDATION FAIL: " + str(packet["id"]), file=sys.stderr)
        print("\n".join(violations), file=sys.stderr)
        return 1
    print(f"TASK VALIDATION PASS: {packet['id']} ({len(changed)} changed paths)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
