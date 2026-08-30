from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image

LOSSLESS_WEBP_METHOD = 4
DEFAULT_PADDING = 6


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def res_path(project_root: Path, path: Path) -> str:
    return "res://" + path.resolve().relative_to(project_root.resolve()).as_posix()


def alpha_bbox(image: Image.Image, threshold: int = 1) -> tuple[int, int, int, int] | None:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if threshold <= 1:
        return alpha.getbbox()
    mask = alpha.point(lambda v: 255 if v >= threshold else 0)
    return mask.getbbox()


def require_alpha(image: Image.Image, source: Path) -> Image.Image:
    if "A" not in image.getbands():
        raise ValueError(f"transparent alpha required for this pack: {source}")
    return image.convert("RGBA")


def trim_rgba(image: Image.Image, padding: int = DEFAULT_PADDING) -> tuple[Image.Image, tuple[int, int, int, int]]:
    rgba = image.convert("RGBA")
    bbox = alpha_bbox(rgba, 1)
    if bbox is None:
        raise ValueError("frame is fully transparent")
    l, t, r, b = bbox
    l = max(0, l - padding)
    t = max(0, t - padding)
    r = min(rgba.width, r + padding)
    b = min(rgba.height, b + padding)
    return rgba.crop((l, t, r, b)), (l, t, r, b)


def bottom_support_pivot(image: Image.Image, alpha_threshold: int = 24) -> tuple[float, float]:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    pixels = alpha.load()
    bottom = -1
    for y in range(rgba.height - 1, -1, -1):
        if any(pixels[x, y] >= alpha_threshold for x in range(rgba.width)):
            bottom = y
            break
    if bottom < 0:
        raise ValueError("cannot derive feet pivot from empty frame")
    xs: list[int] = []
    band_top = max(0, bottom - 5)
    for y in range(band_top, bottom + 1):
        for x in range(rgba.width):
            if pixels[x, y] >= alpha_threshold:
                xs.append(x)
    if not xs:
        return rgba.width * 0.5, float(bottom)
    xs.sort()
    mid = len(xs) // 2
    x_value = float(xs[mid]) if len(xs) % 2 else 0.5 * float(xs[mid - 1] + xs[mid])
    return x_value, float(bottom)


def save_lossless_webp(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(path, format="WEBP", lossless=True, method=LOSSLESS_WEBP_METHOD, exact=True)


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_sprite_frames(project_root: Path, output_path: Path, animations: list[dict]) -> None:
    frame_records: list[tuple[str, float, bool, list[dict]]] = []
    texture_paths: list[str] = []
    for anim in animations:
        frames = list(anim.get("frames", []))
        frame_records.append((str(anim["key"]), float(anim.get("fps", 12.0)), bool(anim.get("loop", False)), frames))
        texture_paths.extend(str(frame["path"]) for frame in frames)

    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(texture_paths) + 1} format=3]', ""]
    for idx, path in enumerate(texture_paths, start=1):
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{idx}"]')
    lines += ["", "[resource]", "animations = ["]
    texture_id = 1
    for anim_index, (key, fps, loop, frames) in enumerate(frame_records):
        lines.append("{")
        # Built outside the f-string: a backslash inside an f-string expression
        # only parses from Python 3.12 (PEP 701), and nothing else in the asset
        # pipeline needs an interpreter that new.
        frame_entries = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%d")}' % (texture_id + i)
            for i in range(len(frames))
        )
        lines.append(f'"frames": [{frame_entries}],')
        lines.append(f'"loop": {str(loop).lower()},')
        lines.append(f'"name": &"{key}",')
        lines.append(f'"speed": {fps}')
        lines.append("}" + ("," if anim_index < len(frame_records) - 1 else ""))
        texture_id += len(frames)
    lines.append("]")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_fighter_visual_scene(project_root: Path, output_path: Path, sprite_frames_path: Path, manifest_path: Path, node_name: str) -> None:
    sprite_res = res_path(project_root, sprite_frames_path)
    manifest_res = res_path(project_root, manifest_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(f'''[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://presentation/visuals/production/production_fighter_visual.gd" id="1"]\n[ext_resource type="SpriteFrames" path="{sprite_res}" id="2"]\n\n[node name="{node_name}" type="Node2D"]\nscript = ExtResource("1")\nsprite_frames = ExtResource("2")\nmanifest_path = "{manifest_res}"\n\n[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\nsprite_frames = ExtResource("2")\ncentered = false\n''', encoding="utf-8")


def write_effect_visual_scene(project_root: Path, output_path: Path, sprite_frames_path: Path, manifest_path: Path, pack_type: str, node_name: str) -> None:
    script = "res://presentation/visuals/production/production_projectile_visual.gd" if pack_type == "PROJECTILE" else "res://presentation/visuals/production/production_world_effect_visual.gd"
    sprite_res = res_path(project_root, sprite_frames_path)
    manifest_res = res_path(project_root, manifest_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(f'''[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="{script}" id="1"]\n[ext_resource type="SpriteFrames" path="{sprite_res}" id="2"]\n\n[node name="{node_name}" type="Node2D"]\nscript = ExtResource("1")\nsprite_frames = ExtResource("2")\nmanifest_path = "{manifest_res}"\nanimation_key = &"effect"\n\n[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\nsprite_frames = ExtResource("2")\ncentered = false\n''', encoding="utf-8")


def write_ultimate_visual_scene(project_root: Path, output_path: Path, manifest_path: Path, node_name: str) -> None:
    manifest_res = res_path(project_root, manifest_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(f'''[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://presentation/ultimates/ultimate_screen_visual.gd" id="1"]\n\n[node name="{node_name}" type="Control"]\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\nscript = ExtResource("1")\nmanifest_path = "{manifest_res}"\n\n[node name="TextureRect" type="TextureRect" parent="."]\nlayout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\nexpand_mode = 1\nstretch_mode = 6\n''', encoding="utf-8")


def load_frame_list(source_root: Path, frame_specs: Iterable[object]) -> list[tuple[Path, dict]]:
    out: list[tuple[Path, dict]] = []
    for item in frame_specs:
        if isinstance(item, str):
            meta: dict = {}
            rel = item
        elif isinstance(item, dict):
            meta = dict(item)
            rel = str(meta.pop("path"))
        else:
            raise ValueError(f"invalid frame spec: {item!r}")
        path = (source_root / rel).resolve()
        if not path.is_file():
            raise FileNotFoundError(path)
        out.append((path, meta))
    return out
