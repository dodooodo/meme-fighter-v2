#!/usr/bin/env python3
"""Build a manifest-backed SpriteFrames resource from recovered action folders."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    return parser.parse_args()


def action_id(round_number: int, number: int) -> str:
    return f"r{round_number}_{number:02d}"


def find_action_dir(source_root: Path, round_number: int, number: int) -> Path:
    round_dir = source_root / f"ROUND_{round_number}"
    matches = sorted(round_dir.glob(f"{number:02d}_*"))
    if len(matches) != 1 or not matches[0].is_dir():
        raise ValueError(f"expected one action folder for round {round_number}, action {number:02d}")
    return matches[0]


def image_number(path: Path) -> int:
    try:
        return int(path.stem)
    except ValueError as exc:
        raise ValueError(f"frame filename must be numeric: {path}") from exc


def frame_metadata(path: Path, resource_path: str, kind: str, source_action: str) -> dict:
    with Image.open(path) as image:
        width, height = image.size
    pivot = [width / 2.0, height / 2.0 if kind == "effect" else float(height)]
    return {
        "path": resource_path,
        "source_action": source_action,
        "width": width,
        "height": height,
        "pivot_pixels": pivot,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def animation_entry(key: str, fps: float, loop: bool, frames: list[dict]) -> dict:
    return {
        "key": key,
        "fps": fps,
        "loop": loop,
        "frame_count": len(frames),
        "frames": [
            {
                "index": index,
                "path": frame["path"],
                "pivot_pixels": frame["pivot_pixels"],
            }
            for index, frame in enumerate(frames, 1)
        ],
    }


def render_sprite_frames(resource_ids: dict[str, str], animations: list[dict]) -> str:
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(resource_ids) + 1} format=3]', ""]
    for path, resource_id in resource_ids.items():
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{resource_id}"]')
    lines.extend(["", "[resource]", "animations = ["])
    for index, animation in enumerate(animations):
        frames = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%s")}' % resource_ids[frame["path"]]
            for frame in animation["frames"]
        )
        comma = "," if index + 1 < len(animations) else ""
        lines.append(
            '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.3f}%s'
            % (frames, str(animation["loop"]).lower(), animation["key"], animation["fps"], comma)
        )
    lines.extend(["]", ""])
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    source_root = args.source_root.resolve()
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    character_id = str(spec["character_id"])
    output_root = project_root / "assets" / "characters" / character_id
    source_output = output_root / "source"
    animations_output = output_root / "animations"
    source_output.mkdir(parents=True, exist_ok=True)
    animations_output.mkdir(parents=True, exist_ok=True)

    actions_by_id: dict[str, dict] = {}
    source_frames: list[dict] = []
    animations: list[dict] = []
    seen_keys: set[str] = set()
    copied_paths: set[str] = set()

    for action in spec["actions"]:
        round_number = int(action["round"])
        number = int(action["number"])
        key = str(action["key"])
        identifier = action_id(round_number, number)
        if identifier in actions_by_id or key in seen_keys:
            raise ValueError(f"duplicate action id or animation key: {identifier} / {key}")
        action_dir = find_action_dir(source_root, round_number, number)
        source_paths = sorted(action_dir.glob("*.webp"), key=image_number)
        if not source_paths:
            raise ValueError(f"action folder has no WebP frames: {action_dir}")
        kind = str(action.get("kind", "body"))
        frames: list[dict] = []
        destination_dir = source_output / f"round_{round_number}"
        destination_dir.mkdir(parents=True, exist_ok=True)
        for source_path in source_paths:
            destination = destination_dir / source_path.name
            shutil.copy2(source_path, destination)
            resource_path = f"res://assets/characters/{character_id}/source/round_{round_number}/{destination.name}"
            if resource_path in copied_paths:
                raise ValueError(f"duplicate destination frame: {resource_path}")
            copied_paths.add(resource_path)
            metadata = frame_metadata(source_path, resource_path, kind, action_dir.name)
            frames.append(metadata)
            source_frames.append({"round": round_number, "action": number, **metadata})
        actions_by_id[identifier] = {"frames": frames, "kind": kind}
        animations.append(animation_entry(key, float(action.get("fps", 8.0)), bool(action.get("loop", False)), frames))
        seen_keys.add(key)

    for composite in spec.get("composites", []):
        key = str(composite["key"])
        if key in seen_keys:
            raise ValueError(f"duplicate composite animation key: {key}")
        frames: list[dict] = []
        for identifier in composite["sources"]:
            if identifier not in actions_by_id:
                raise ValueError(f"unknown composite action: {identifier}")
            frames.extend(actions_by_id[identifier]["frames"])
        animations.append(animation_entry(key, float(composite.get("fps", 8.0)), bool(composite.get("loop", False)), frames))
        seen_keys.add(key)

    expected_count = int(spec.get("expected_source_frame_count", len(source_frames)))
    if len(source_frames) != expected_count:
        raise ValueError(f"expected {expected_count} source frames, found {len(source_frames)}")

    source_frames.sort(key=lambda item: (item["round"], item["action"], int(Path(item["path"]).stem)))
    manifest = {
        "manifest_version": 3,
        "asset_version": 1,
        "character_id": character_id,
        "character_asset_key": character_id,
        "pack_type": "BASE_FIGHTER",
        "source": str(spec.get("source", "recovered_action_folders")),
        "source_layout": "ACTION_FOLDERS",
        "pivot_convention": "FEET_CENTER",
        "source_frame_count": len(source_frames),
        "source_frames": source_frames,
        "animations": animations,
    }
    manifest_path = animations_output / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    checksum_lines = [
        f'{frame["sha256"]}  {frame["path"].removeprefix("res://assets/characters/" + character_id + "/")}'
        for frame in source_frames
    ]
    (source_output / "source_bundle.sha256").write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")

    ordered_paths = sorted(copied_paths)
    resource_ids = {path: str(index) for index, path in enumerate(ordered_paths, 1)}
    sprite_frames_path = animations_output / f"{character_id}_sprite_frames.tres"
    sprite_frames_path.write_text(render_sprite_frames(resource_ids, animations), encoding="utf-8")
    print(f"Built {character_id}: {len(source_frames)} source frames, {len(animations)} animations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
