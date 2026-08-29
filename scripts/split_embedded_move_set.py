#!/usr/bin/env python3
"""Split an embedded MoveSetData .tres into package-owned MoveData resources."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


EXT_RE = re.compile(r'^\[ext_resource .* id="([^"]+)"\]$', re.MULTILINE)
SUB_RE = re.compile(r'^\[sub_resource .* id="([^"]+)"\]\n', re.MULTILINE)
SUB_REF_RE = re.compile(r'SubResource\("([^"]+)"\)')
EXT_REF_RE = re.compile(r'ExtResource\("([^"]+)"\)')
MOVE_ID_RE = re.compile(r'^id = &"([^"]+)"$', re.MULTILINE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    return parser.parse_args()


def blocks(source: str, marker: re.Pattern[str]) -> dict[str, str]:
    matches = list(marker.finditer(source))
    result: dict[str, str] = {}
    for index, match in enumerate(matches):
        next_headers = [position for position in (source.find("\n[sub_resource", match.end()), source.find("\n[resource]", match.end())) if position >= 0]
        end = min(next_headers) if next_headers else len(source)
        result[match.group(1)] = source[match.start():end].strip() + "\n"
    return result


def ext_blocks(source: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in source.splitlines():
        if not line.startswith("[ext_resource"):
            continue
        match = re.search(r'id="([^"]+)"', line)
        if match:
            result[match.group(1)] = line
    return result


def dependency_closure(root_id: str, subresources: dict[str, str]) -> list[str]:
    ordered: list[str] = []
    seen: set[str] = set()

    def visit(identifier: str) -> None:
        if identifier in seen:
            return
        if identifier not in subresources:
            raise ValueError(f"unknown SubResource reference: {identifier}")
        seen.add(identifier)
        for dependency in SUB_REF_RE.findall(subresources[identifier]):
            visit(dependency)
        ordered.append(identifier)

    visit(root_id)
    ordered.remove(root_id)
    return ordered


def main() -> int:
    args = parse_args()
    project_root = Path(__file__).resolve().parents[1]
    resource_root = "res://" + args.output_root.resolve().relative_to(project_root).as_posix()
    source = args.source.read_text(encoding="utf-8")
    subresources = blocks(source, SUB_RE)
    external = ext_blocks(source)
    move_roots: list[tuple[str, str]] = []
    for identifier, block in subresources.items():
        if 'script = ExtResource("move")' not in block:
            continue
        move_id = MOVE_ID_RE.search(block)
        if move_id:
            move_roots.append((identifier, move_id.group(1)))
    if len(move_roots) < 7:
        raise ValueError(f"expected at least seven embedded moves, found {len(move_roots)}")

    moves_root = args.output_root / "moves"
    moves_root.mkdir(parents=True, exist_ok=True)
    for root_id, move_id in move_roots:
        dependencies = dependency_closure(root_id, subresources)
        bodies = [subresources[identifier] for identifier in dependencies] + [subresources[root_id]]
        used_ext_ids: set[str] = set()
        for body in bodies:
            used_ext_ids.update(EXT_REF_RE.findall(body))
        missing = used_ext_ids.difference(external)
        if missing:
            raise ValueError(f"unknown ExtResource references for {move_id}: {sorted(missing)}")
        resource_body = subresources[root_id].split("\n", 1)[1]
        load_steps = len(used_ext_ids) + len(dependencies) + 1
        output = [f'[gd_resource type="Resource" load_steps={load_steps} format=3]', ""]
        output.extend(external[identifier] for identifier in external if identifier in used_ext_ids)
        output.append("")
        output.extend(subresources[identifier].rstrip() + "\n" for identifier in dependencies)
        output.extend(["[resource]", resource_body.rstrip(), ""])
        (moves_root / f"{move_id}.tres").write_text("\n".join(output), encoding="utf-8")

    move_set_lines = [f'[gd_resource type="Resource" load_steps={len(move_roots) + 3} format=3]', ""]
    move_set_lines.append(external["set"])
    move_set_lines.append(external["move"])
    for index, (_root_id, move_id) in enumerate(move_roots, 1):
        move_set_lines.append(
            f'[ext_resource type="Resource" path="{resource_root}/moves/{move_id}.tres" id="move_{index}"]'
        )
    refs = ", ".join(f'ExtResource("move_{index}")' for index in range(1, len(move_roots) + 1))
    move_set_lines.extend(["", "[resource]", 'script = ExtResource("set")', f'moves = Array[ExtResource("move")]([{refs}])', ""])
    (args.output_root / "move_set.tres").write_text("\n".join(move_set_lines), encoding="utf-8")
    print(f"Split {len(move_roots)} moves into {moves_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
