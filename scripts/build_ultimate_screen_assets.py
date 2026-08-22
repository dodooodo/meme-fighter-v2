#!/usr/bin/env python3
"""Build ULTIMATE_SCREEN presentation packs to canonical 1280x720.

Source must be approximately 16:9. Any small mismatch is center-cropped before resize,
so artwork is never stretched. RGB and RGBA are both valid. Gameplay timing is not read.
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
from presentation_asset_pipeline.common import load_frame_list, res_path, sha256_file, write_json, write_ultimate_visual_scene  # noqa: E402

PACK_TYPE = "ULTIMATE_SCREEN"
MANIFEST_VERSION = 3
TARGET_SIZE = (1280, 720)
TARGET_RATIO = 16.0 / 9.0
RATIO_TOLERANCE = 0.035


def normalize_16_9(image: Image.Image) -> tuple[Image.Image, list[int]]:
    ratio = image.width / max(1.0, float(image.height))
    if abs(ratio - TARGET_RATIO) / TARGET_RATIO > RATIO_TOLERANCE:
        raise ValueError(f"ULTIMATE_SCREEN source must be approximately 16:9, got {image.width}x{image.height}")
    if ratio > TARGET_RATIO:
        crop_w = int(round(image.height * TARGET_RATIO))
        left = (image.width - crop_w) // 2
        box = [left, 0, left + crop_w, image.height]
    else:
        crop_h = int(round(image.width / TARGET_RATIO))
        top = (image.height - crop_h) // 2
        box = [0, top, image.width, top + crop_h]
    cropped = image.crop(tuple(box))
    mode = "RGBA" if "A" in image.getbands() else "RGB"
    return cropped.convert(mode).resize(TARGET_SIZE, Image.Resampling.LANCZOS), box


def build(project_root: Path, spec_path: Path, source_root: Path | None, output_root: Path | None) -> dict:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    if spec.get("pack_type") != PACK_TYPE:
        raise ValueError(f"pack_type must be {PACK_TYPE}")
    character_asset_key = str(spec.get("character_asset_key", "")).strip()
    ultimate_id = str(spec.get("ultimate_id", "ultimate")).strip()
    screen_id = str(spec.get("screen_id", f"{ultimate_id}_background")).strip()
    if not character_asset_key or not screen_id:
        raise ValueError("character_asset_key and screen_id are required")
    source_root = (source_root or spec_path.parent).resolve()
    output_root = (output_root or (project_root / "assets/characters" / character_asset_key / "ultimate" / screen_id)).resolve()
    if output_root.exists():
        shutil.rmtree(output_root)
    frames_root = output_root / "frames"
    frames_root.mkdir(parents=True, exist_ok=True)

    if "frames" in spec:
        frame_specs = load_frame_list(source_root, spec["frames"])
    elif "source" in spec:
        frame_specs = load_frame_list(source_root, [str(spec["source"])])
    else:
        raise ValueError("ULTIMATE_SCREEN spec requires source or frames[]")

    frames: list[dict] = []
    for index, (path, _meta) in enumerate(frame_specs, start=1):
        opened = Image.open(path)
        normalized, crop_box = normalize_16_9(opened)
        out_path = frames_root / f"{screen_id}_{index:03d}.webp"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        normalized.save(out_path, format="WEBP", lossless=True, method=4, exact=True)
        frames.append({
            "index": index,
            "path": res_path(project_root, out_path),
            "source": path.as_posix(),
            "source_size": [opened.width, opened.height],
            "source_crop_rect": crop_box,
            "runtime_size": list(TARGET_SIZE),
            "sha256": sha256_file(out_path),
        })

    manifest_path = output_root / "manifest.json"
    visual_scene_path = output_root / f"{screen_id}_visual.tscn"
    manifest = {
        "manifest_version": MANIFEST_VERSION,
        "pack_type": PACK_TYPE,
        "character_asset_key": character_asset_key,
        "ultimate_id": ultimate_id,
        "screen_id": screen_id,
        "runtime_size": list(TARGET_SIZE),
        "aspect_ratio": "16:9",
        "fps": float(spec.get("fps", 1.0)),
        "loop": bool(spec.get("loop", False)),
        "frame_count": len(frames),
        "frames": frames,
        "visual_scene": res_path(project_root, visual_scene_path),
        "gameplay_timing_authority": "NONE_PRESENTATION_ONLY",
    }
    write_json(manifest_path, manifest)
    write_ultimate_visual_scene(project_root, visual_scene_path, manifest_path, f"{screen_id}_visual")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--output-root", type=Path)
    args = parser.parse_args()
    manifest = build(args.project_root.resolve(), args.spec.resolve(), args.source_root, args.output_root)
    print(f"ULTIMATE_SCREEN {manifest['screen_id']}: {manifest['frame_count']} frame(s) -> 1280x720")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
