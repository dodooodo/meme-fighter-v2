#!/usr/bin/env python3
"""Build manifest-driven MODE_FIGHTER presentation assets.

Unlike BASE_FIGHTER, this pipeline has no 10-sheet/250-frame/square-canvas rule.
Frames remain at source scale, are only safely tight-cropped with transparent margin,
and carry a per-frame FEET_CENTER pivot. Gameplay data is never read or written.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from presentation_asset_pipeline.common import (  # noqa: E402
    alpha_bbox,
    bottom_support_pivot,
    load_frame_list,
    require_alpha,
    res_path,
    save_lossless_webp,
    sha256_file,
    trim_rgba,
    write_fighter_visual_scene,
    write_json,
    write_sprite_frames,
)

PACK_TYPE = "MODE_FIGHTER"
MANIFEST_VERSION = 3
DEFAULT_PADDING = 8


def _images_from_animation(source_root: Path, anim: dict) -> list[tuple[Image.Image, str, dict]]:
    if "frames" in anim:
        out = []
        for path, meta in load_frame_list(source_root, anim["frames"]):
            out.append((Image.open(path), path.as_posix(), meta))
        return out

    source = anim.get("source")
    if not isinstance(source, dict):
        raise ValueError(f"animation {anim.get('key')} requires frames[] or source")
    source_type = str(source.get("type", "")).lower()
    path = (source_root / str(source.get("path", ""))).resolve()
    if not path.is_file():
        raise FileNotFoundError(path)
    image = Image.open(path)
    out: list[tuple[Image.Image, str, dict]] = []
    if source_type == "grid":
        columns = int(source.get("columns", 0))
        rows = int(source.get("rows", 0))
        frame_count = int(source.get("frame_count", columns * rows))
        if columns <= 0 or rows <= 0 or image.width % columns != 0 or image.height % rows != 0:
            raise ValueError(f"manifest-defined grid must divide exactly: {path}")
        cw, ch = image.width // columns, image.height // rows
        if frame_count < 1 or frame_count > columns * rows:
            raise ValueError("invalid grid frame_count")
        for index in range(frame_count):
            row, col = divmod(index, columns)
            rect = (col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)
            out.append((image.crop(rect), f"{path.as_posix()}#cell={index + 1}", {}))
        return out
    if source_type in {"horizontal_strip", "vertical_strip"}:
        frame_count = int(source.get("frame_count", 0))
        if frame_count <= 0:
            raise ValueError("strip frame_count must be > 0")
        if source_type == "horizontal_strip":
            if image.width % frame_count != 0:
                raise ValueError("horizontal strip width must divide by frame_count")
            fw = image.width // frame_count
            for index in range(frame_count):
                out.append((image.crop((index * fw, 0, (index + 1) * fw, image.height)), f"{path.as_posix()}#frame={index + 1}", {}))
        else:
            if image.height % frame_count != 0:
                raise ValueError("vertical strip height must divide by frame_count")
            fh = image.height // frame_count
            for index in range(frame_count):
                out.append((image.crop((0, index * fh, image.width, (index + 1) * fh)), f"{path.as_posix()}#frame={index + 1}", {}))
        return out
    raise ValueError(f"unsupported mode source type: {source_type}")


def build(project_root: Path, spec_path: Path, source_root: Path | None, output_root: Path | None) -> dict:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    if spec.get("pack_type") != PACK_TYPE:
        raise ValueError(f"pack_type must be {PACK_TYPE}")
    character_asset_key = str(spec.get("character_asset_key", "")).strip()
    character_id = str(spec.get("character_id", "")).strip()
    mode_id = str(spec.get("mode_id", "")).strip()
    if not character_asset_key or not character_id or not mode_id:
        raise ValueError("character_asset_key, character_id and mode_id are required")
    source_root = (source_root or spec_path.parent).resolve()
    output_root = (output_root or (project_root / "assets/characters" / character_asset_key / "modes" / mode_id)).resolve()
    if output_root.exists():
        shutil.rmtree(output_root)
    frames_root = output_root / "frames"
    animations_dir = output_root / "animations"
    padding = int(spec.get("transparent_padding", DEFAULT_PADDING))
    if padding < 1:
        raise ValueError("transparent_padding must be >= 1")

    animations_out: list[dict] = []
    source_hashes: dict[str, str] = {}
    total_frames = 0
    max_width = max_height = 0
    min_width = min_height = 1 << 30

    for anim in spec.get("animations", []):
        key = str(anim.get("key", "")).strip()
        if not key:
            raise ValueError("animation key is required")
        fps = float(anim.get("fps", 8.0))
        loop = bool(anim.get("loop", False))
        source_frames = _images_from_animation(source_root, anim)
        if not source_frames:
            raise ValueError(f"animation {key} has no frames")
        frame_meta: list[dict] = []
        for index, (opened, source_label, metadata) in enumerate(source_frames, start=1):
            # MODE_FIGHTER requires real alpha; no color-key/background guessing.
            rgba = require_alpha(opened, Path(source_label.split("#", 1)[0]))
            if alpha_bbox(rgba) is None:
                raise ValueError(f"empty mode frame: {source_label}")
            tight, crop_rect = trim_rgba(rgba, padding)
            pivot_override = metadata.get("pivot_pixels")
            if isinstance(pivot_override, list) and len(pivot_override) == 2:
                pivot = (float(pivot_override[0]) - crop_rect[0], float(pivot_override[1]) - crop_rect[1])
                pivot_method = "MANIFEST_OVERRIDE"
            else:
                pivot = bottom_support_pivot(tight)
                pivot_method = "BODY_BOTTOM_SUPPORT"
            if not (0.0 <= pivot[0] < tight.width and 0.0 <= pivot[1] < tight.height):
                raise ValueError(f"pivot outside frame for {source_label}: {pivot}")
            out_path = frames_root / key / f"{key}_{index:03d}.webp"
            save_lossless_webp(tight, out_path)
            source_file = Path(source_label.split("#", 1)[0])
            if source_file.is_file():
                source_hashes[source_file.as_posix()] = sha256_file(source_file)
            bbox = alpha_bbox(tight)
            assert bbox is not None
            margins = [bbox[0], tight.width - bbox[2], bbox[1], tight.height - bbox[3]]
            frame_meta.append({
                "index": index,
                "path": res_path(project_root, out_path),
                "source": source_label,
                "source_crop_rect": list(crop_rect),
                "runtime_size": [tight.width, tight.height],
                "foreground_bbox": list(bbox),
                "margins": margins,
                "pivot_pixels": [round(pivot[0], 3), round(pivot[1], 3)],
                "pivot_method": pivot_method,
                "sha256": sha256_file(out_path),
                "border_touch": min(margins) <= 0,
            })
            total_frames += 1
            max_width = max(max_width, tight.width)
            max_height = max(max_height, tight.height)
            min_width = min(min_width, tight.width)
            min_height = min(min_height, tight.height)
        animations_out.append({
            "key": key,
            "fps": fps,
            "loop": loop,
            "frame_count": len(frame_meta),
            "frames": frame_meta,
        })

    required = [str(v) for v in spec.get("required_animations", [])]
    keys = {a["key"] for a in animations_out}
    missing = [key for key in required if key not in keys]
    if missing:
        raise ValueError(f"required animations missing: {missing}")

    sprite_frames_path = animations_dir / f"{mode_id}_sprite_frames.tres"
    manifest_path = animations_dir / "manifest.json"
    visual_scene_path = output_root / f"{mode_id}_visual.tscn"
    manifest = {
        "manifest_version": MANIFEST_VERSION,
        "pack_type": PACK_TYPE,
        "character_asset_key": character_asset_key,
        "character_id": character_id,
        "mode_id": mode_id,
        "display_name": str(spec.get("display_name", mode_id)),
        "canonical_facing": "RIGHT",
        "pivot_convention": "FEET_CENTER",
        "runtime_layout": "TIGHT_PIVOT",
        "square_canvas_required": False,
        "resize_body": False,
        "visual_scale": float(spec.get("visual_scale", 1.0)),
        "visual_offset_pixels": spec.get("visual_offset_pixels", [0, 0]),
        "required_animations": required,
        "frame_count": total_frames,
        "frame_size_range": {"min": [min_width, min_height], "max": [max_width, max_height]},
        "animations": animations_out,
        "source_files": [{"path": path, "sha256": digest} for path, digest in sorted(source_hashes.items())],
        "sprite_frames_resource": res_path(project_root, sprite_frames_path),
        "visual_scene": res_path(project_root, visual_scene_path),
        "gameplay_geometry_authority": "NONE_PRESENTATION_ONLY",
    }
    write_json(manifest_path, manifest)
    write_sprite_frames(project_root, sprite_frames_path, animations_out)
    write_fighter_visual_scene(project_root, visual_scene_path, sprite_frames_path, manifest_path, f"{mode_id}_visual")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--output-root", type=Path)
    args = parser.parse_args()
    manifest = build(args.project_root.resolve(), args.spec.resolve(), args.source_root, args.output_root)
    print(f"MODE_FIGHTER {manifest['character_asset_key']}/{manifest['mode_id']}: {manifest['frame_count']} frames")
    print(f"Visual: {manifest['visual_scene']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
