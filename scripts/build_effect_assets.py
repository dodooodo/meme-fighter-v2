#!/usr/bin/env python3
"""Build PROJECTILE / WORLD_EFFECT / HAZARD / ATTACHMENT presentation packs.

No square-canvas rule exists here. Source may be individual RGBA frames, an explicit
horizontal/vertical strip, or an explicit manifest-defined grid. Dimensions/aspect
ratio are preserved; gameplay projectile/hazard boxes are not read or changed.
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
    load_frame_list,
    require_alpha,
    res_path,
    save_lossless_webp,
    sha256_file,
    write_effect_visual_scene,
    write_json,
    write_sprite_frames,
)

ALLOWED_PACK_TYPES = {"PROJECTILE", "WORLD_EFFECT", "HAZARD", "ATTACHMENT"}
MANIFEST_VERSION = 3


def source_frames(source_root: Path, spec: dict) -> list[tuple[Image.Image, str, dict]]:
    if "frames" in spec:
        return [(Image.open(path), path.as_posix(), meta) for path, meta in load_frame_list(source_root, spec["frames"])]
    source = spec.get("source")
    if not isinstance(source, dict):
        raise ValueError("effect spec requires frames[] or source")
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
            raise ValueError("manifest-defined grid must divide exactly")
        cw, ch = image.width // columns, image.height // rows
        for index in range(frame_count):
            row, col = divmod(index, columns)
            out.append((image.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)), f"{path.as_posix()}#cell={index + 1}", {}))
        return out
    if source_type in {"horizontal_strip", "vertical_strip"}:
        frame_count = int(source.get("frame_count", 0))
        if frame_count <= 0:
            raise ValueError("strip frame_count must be > 0")
        if source_type == "horizontal_strip":
            if image.width % frame_count != 0:
                raise ValueError("strip width must divide by frame_count")
            fw = image.width // frame_count
            for index in range(frame_count):
                out.append((image.crop((index * fw, 0, (index + 1) * fw, image.height)), f"{path.as_posix()}#frame={index + 1}", {}))
        else:
            if image.height % frame_count != 0:
                raise ValueError("strip height must divide by frame_count")
            fh = image.height // frame_count
            for index in range(frame_count):
                out.append((image.crop((0, index * fh, image.width, (index + 1) * fh)), f"{path.as_posix()}#frame={index + 1}", {}))
        return out
    raise ValueError(f"unsupported effect source type: {source_type}")


def build(project_root: Path, spec_path: Path, source_root: Path | None, output_root: Path | None) -> dict:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    pack_type = str(spec.get("pack_type", ""))
    if pack_type not in ALLOWED_PACK_TYPES:
        raise ValueError(f"pack_type must be one of {sorted(ALLOWED_PACK_TYPES)}")
    effect_id = str(spec.get("effect_id", spec.get("attachment_id", ""))).strip()
    character_asset_key = str(spec.get("character_asset_key", "shared")).strip()
    if not effect_id:
        raise ValueError("effect_id/attachment_id is required")
    source_root = (source_root or spec_path.parent).resolve()
    domain_folder = {
        "PROJECTILE": "projectiles",
        "WORLD_EFFECT": "effects",
        "HAZARD": "hazards",
        "ATTACHMENT": "attachments",
    }[pack_type]
    output_root = (output_root or (project_root / "assets/characters" / character_asset_key / domain_folder / effect_id)).resolve()
    if output_root.exists():
        shutil.rmtree(output_root)
    frames_dir = output_root / "frames"
    animation_dir = output_root / "animations"

    source_items = source_frames(source_root, spec)
    if not source_items:
        raise ValueError("pack has no frames")
    fps = float(spec.get("fps", 12.0))
    loop = bool(spec.get("loop", False))
    anchor = str(spec.get("anchor", "CENTER"))
    out_frames: list[dict] = []
    source_hashes: dict[str, str] = {}
    max_w = max_h = 0
    min_w = min_h = 1 << 30

    for index, (opened, source_label, meta) in enumerate(source_items, start=1):
        rgba = require_alpha(opened, Path(source_label.split("#", 1)[0]))
        bbox = alpha_bbox(rgba)
        if bbox is None:
            raise ValueError(f"empty effect frame: {source_label}")
        pivot_value = meta.get("pivot_pixels", spec.get("pivot_pixels"))
        if isinstance(pivot_value, list) and len(pivot_value) == 2:
            pivot = [float(pivot_value[0]), float(pivot_value[1])]
        elif anchor == "BOTTOM_CENTER":
            pivot = [rgba.width * 0.5, float(rgba.height - 1)]
        else:
            pivot = [rgba.width * 0.5, rgba.height * 0.5]
        if not (0.0 <= pivot[0] <= rgba.width and 0.0 <= pivot[1] <= rgba.height):
            raise ValueError(f"pivot outside frame: {source_label} -> {pivot}")
        out_path = frames_dir / f"{effect_id}_{index:03d}.webp"
        save_lossless_webp(rgba, out_path)
        source_file = Path(source_label.split("#", 1)[0])
        if source_file.is_file():
            source_hashes[source_file.as_posix()] = sha256_file(source_file)
        out_frames.append({
            "index": index,
            "path": res_path(project_root, out_path),
            "source": source_label,
            "runtime_size": [rgba.width, rgba.height],
            "foreground_bbox": list(bbox),
            "pivot_pixels": [round(pivot[0], 3), round(pivot[1], 3)],
            "sha256": sha256_file(out_path),
            "border_touch": bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= rgba.width or bbox[3] >= rgba.height,
        })
        max_w, max_h = max(max_w, rgba.width), max(max_h, rgba.height)
        min_w, min_h = min(min_w, rgba.width), min(min_h, rgba.height)

    animation = {"key": "effect", "fps": fps, "loop": loop, "frame_count": len(out_frames), "frames": out_frames}
    sprite_frames_path = animation_dir / f"{effect_id}_sprite_frames.tres"
    manifest_path = animation_dir / "manifest.json"
    visual_scene_path = output_root / f"{effect_id}_visual.tscn"
    manifest = {
        "manifest_version": MANIFEST_VERSION,
        "pack_type": pack_type,
        "character_asset_key": character_asset_key,
        "effect_id": effect_id,
        "fps": fps,
        "loop": loop,
        "anchor": anchor,
        "aspect_ratio_restriction": "NONE",
        "square_canvas_required": False,
        "resize_effect": False,
        "frame_count": len(out_frames),
        "frame_size_range": {"min": [min_w, min_h], "max": [max_w, max_h]},
        "frames": out_frames,
        "animations": [animation],
        "source_files": [{"path": path, "sha256": digest} for path, digest in sorted(source_hashes.items())],
        "sprite_frames_resource": res_path(project_root, sprite_frames_path),
        "visual_scene": res_path(project_root, visual_scene_path),
        "gameplay_geometry_authority": "NONE_PRESENTATION_ONLY",
    }
    write_json(manifest_path, manifest)
    write_sprite_frames(project_root, sprite_frames_path, [animation])
    write_effect_visual_scene(project_root, visual_scene_path, sprite_frames_path, manifest_path, pack_type, f"{effect_id}_visual")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--output-root", type=Path)
    args = parser.parse_args()
    manifest = build(args.project_root.resolve(), args.spec.resolve(), args.source_root, args.output_root)
    print(f"{manifest['pack_type']} {manifest['effect_id']}: {manifest['frame_count']} frames")
    print(f"Visual: {manifest['visual_scene']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
