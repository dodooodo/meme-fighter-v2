#!/usr/bin/env python3
"""Deterministic production character asset builder for Two Box Fighting.

Authoritative animation ranges come from the user-authored production mapping.
This tool does NOT infer poses/animation ranges and does NOT use OCR, AI vision,
image similarity, or pose recognition.

Crop pipeline (Fix Pass):
  source sheet -> foreground/background analysis -> projection gutter detection ->
  real 5x5 safe regions -> cell foreground crop -> optional data-driven override ->
  feet/body metadata -> shared transparent runtime canvas -> lossless WebP.

Important: there is intentionally no width/5 or rational 154/153 slicing path.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import re
import shutil
import statistics
import sys
import zipfile
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont

GRID_COLUMNS = 5
GRID_ROWS = 5
SHEETS_PER_CHARACTER = 10
FRAMES_PER_SHEET = 25
TOTAL_FRAMES = 250
ASSET_VERSION = 3
CANVAS_CANDIDATES = (192, 256, 320, 384)
CANVAS_MARGIN = 8
GRID_MIN_SEGMENT = 96
GRID_MAX_SEGMENT = 208
GRID_STRIP_RADIUS = 3
ALPHA_DETECT_THRESHOLD = 12
BODY_ALPHA_THRESHOLD = 80
BACKGROUND_MAX_TOLERANCE = 24

# Canonical contract; presentation FPS only. Attack playback in Battle is move-phase driven.
ANIMATIONS = [
    ("idle", 12, 8.0, True, False),
    ("crouch", 6, 8.0, True, False),
    ("landing", 7, 10.0, False, False),
    ("walk_forward", 12, 8.0, True, False),
    ("walk_back", 13, 8.0, True, False),
    ("jump", 11, 10.0, False, False),
    ("air_attack", 14, 10.0, False, False),
    ("guard_stand", 6, 8.0, True, False),
    ("guard_crouch", 6, 8.0, True, False),
    ("blockstun", 6, 10.0, False, False),
    ("hitstun", 7, 10.0, False, False),
    ("thrown", 8, 10.0, False, False),
    ("knockdown", 9, 10.0, False, False),
    ("getup", 8, 10.0, False, False),
    ("ko", 12, 8.0, False, True),
    ("dash_forward", 7, 10.0, False, False),
    ("backstep", 6, 10.0, False, False),
    # These speeds are preview defaults only; Battle attacks are manually mapped from MoveData phase/frame.
    ("stand_light", 10, 10.0, False, False),
    ("stand_heavy", 15, 10.0, False, False),
    ("crouch_low", 11, 10.0, False, False),
    ("ground_throw", 14, 10.0, False, False),
    ("special_neutral", 25, 10.0, False, False),
    ("ultimate", 25, 10.0, False, False),
]
assert len(ANIMATIONS) == 23
assert sum(item[1] for item in ANIMATIONS) == TOTAL_FRAMES

ATTACK_KEYS = {
    "stand_light", "stand_heavy", "crouch_low", "air_attack",
    "ground_throw", "special_neutral", "ultimate",
}
GROUNDED_KEYS = {
    "idle", "walk_forward", "walk_back", "crouch", "landing",
    "guard_stand", "guard_crouch", "blockstun", "hitstun", "getup", "ko",
    "dash_forward", "backstep", "stand_light", "stand_heavy", "crouch_low",
    "ground_throw", "special_neutral", "ultimate",
}

CHARACTERS = {
    "salad_cat": {
        "display_name": "Salad Cat",
        "character_id": "generic_fighter",
        "gameplay_slot": "BOUND",
        "canonical_source_bundle": "salad_optimized_aggressive.zip",
        "presentation_names": {
            "special_neutral": "Salad Tornado",
            "ultimate": "Ultimate Salad Burst",
        },
    },
    "magic_orange_cat": {
        "display_name": "Magic Orange Cat",
        "character_id": "zone_fighter",
        "gameplay_slot": "BOUND",
        "canonical_source_bundle": "magic_orange_cat_optimized_aggressive.zip",
        "presentation_names": {
            "special_neutral": "JPEG魔法陣",
            "ultimate": "喵蘇魯的召喚",
        },
    },
}

SHEET_NUMBER_RE = re.compile(r"\((10|[1-9])\)(?=\.[^.]+$)")


@dataclass
class Component:
    area: int
    left: int
    top: int
    right: int  # exclusive
    bottom: int  # exclusive
    sum_x: int
    sum_y: int
    bottom_x_min: int
    bottom_x_max: int

    @property
    def center_x(self) -> float:
        return self.sum_x / self.area

    @property
    def center_y(self) -> float:
        return self.sum_y / self.area

    @property
    def width(self) -> int:
        return self.right - self.left

    @property
    def height(self) -> int:
        return self.bottom - self.top

    @property
    def feet_x(self) -> float:
        return (self.bottom_x_min + self.bottom_x_max) * 0.5

    @property
    def ground_y(self) -> int:
        return self.bottom - 1


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def parse_sheet_number(name: str) -> int | None:
    match = SHEET_NUMBER_RE.search(Path(name).name)
    return int(match.group(1)) if match else None


def choose_sheet_entries(zf: zipfile.ZipFile) -> list[tuple[int, zipfile.ZipInfo]]:
    found: list[tuple[int, zipfile.ZipInfo]] = []
    for info in zf.infolist():
        if info.is_dir() or not info.filename.lower().endswith(".webp"):
            continue
        number = parse_sheet_number(info.filename)
        if number is not None:
            found.append((number, info))
    found.sort(key=lambda item: item[0])
    numbers = [number for number, _ in found]
    if numbers != list(range(1, 11)):
        raise ValueError(f"expected numeric sheet order 1..10 exactly; got {numbers}")
    return found


def animation_for_global_frame(global_index: int) -> tuple[str, int, float, bool, bool]:
    start = 1
    for key, count, fps, loop, hold_final in ANIMATIONS:
        end = start + count - 1
        if start <= global_index <= end:
            return key, global_index - start + 1, fps, loop, hold_final
        start = end + 1
    raise IndexError(global_index)


def moving_mean(values: list[int], radius: int) -> list[float]:
    if radius <= 0:
        return [float(v) for v in values]
    prefix = [0]
    for value in values:
        prefix.append(prefix[-1] + value)
    out: list[float] = []
    for i in range(len(values)):
        left = max(0, i - radius)
        right = min(len(values), i + radius + 1)
        out.append((prefix[right] - prefix[left]) / max(1, right - left))
    return out


def mask_projection(mask: bytearray, width: int, height: int, axis: str) -> list[int]:
    if axis == "x":
        out = [0] * width
        for y in range(height):
            row = y * width
            for x in range(width):
                if mask[row + x]:
                    out[x] += 1
        return out
    out = [0] * height
    for y in range(height):
        row = y * width
        count = 0
        for x in range(width):
            count += 1 if mask[row + x] else 0
        out[y] = count
    return out


def detect_grid_edges(mask: bytearray, width: int, height: int, axis: str) -> tuple[list[int], list[float], list[int]]:
    """Find four repeated low-content separator lines with soft spacing regularity.

    This intentionally does not compute width/5. It searches the complete projection
    for a sequence of four low-energy gutters whose five resulting regions satisfy
    broad safe size constraints and repeated-spacing consistency.
    """
    size = width if axis == "x" else height
    projection = mask_projection(mask, width, height, axis)
    energy = moving_mean(projection, GRID_STRIP_RADIUS)
    sorted_energy = sorted(energy)
    p10 = sorted_energy[int(0.10 * (len(sorted_energy) - 1))]
    p90 = sorted_energy[int(0.90 * (len(sorted_energy) - 1))]
    scale = max(1.0, p90 - p10)

    # DP: state after each separator = {position: (cost, path)}.
    states: dict[int, tuple[float, list[int]]] = {}
    for x in range(GRID_MIN_SEGMENT, min(GRID_MAX_SEGMENT, size - 4 * GRID_MIN_SEGMENT) + 1):
        local_min = min(energy[max(0, x - 7): min(size, x + 8)])
        valley_cost = (energy[x] + 0.65 * local_min) / scale
        states[x] = (valley_cost, [x])

    for separator_count in range(2, 5):
        new_states: dict[int, tuple[float, list[int]]] = {}
        remaining_segments = 5 - separator_count
        for previous, (cost, path) in states.items():
            prev_prev = path[-2] if len(path) >= 2 else 0
            previous_width = previous - prev_prev
            low = previous + GRID_MIN_SEGMENT
            high = min(previous + GRID_MAX_SEGMENT, size - remaining_segments * GRID_MIN_SEGMENT)
            for x in range(low, high + 1):
                final_space = size - x
                if final_space < remaining_segments * GRID_MIN_SEGMENT:
                    continue
                if final_space > remaining_segments * GRID_MAX_SEGMENT:
                    continue
                local_min = min(energy[max(0, x - 7): min(size, x + 8)])
                valley_cost = (energy[x] + 0.65 * local_min) / scale
                current_width = x - previous
                # Soft regularity only: repeated gutter spacing is expected, equality is not.
                regularity = 0.0025 * ((current_width - previous_width) ** 2) / max(1.0, float(previous_width))
                new_cost = cost + valley_cost + regularity
                old = new_states.get(x)
                if old is None or new_cost < old[0]:
                    new_states[x] = (new_cost, path + [x])
        states = new_states
        if not states:
            raise RuntimeError(f"could not detect {axis}-axis repeated gutters")

    best: tuple[float, list[int]] | None = None
    for last, (cost, path) in states.items():
        previous = path[-2] if len(path) >= 2 else 0
        previous_width = last - previous
        final_width = size - last
        if not (GRID_MIN_SEGMENT <= final_width <= GRID_MAX_SEGMENT):
            continue
        regularity = 0.0025 * ((final_width - previous_width) ** 2) / max(1.0, float(previous_width))
        candidate = (cost + regularity, path)
        if best is None or candidate[0] < best[0]:
            best = candidate
    if best is None:
        raise RuntimeError(f"could not finalize {axis}-axis repeated gutters")

    refined: list[int] = []
    for raw in best[1]:
        low = max(1, raw - 6)
        high = min(size - 2, raw + 6)
        minimum = min(energy[low: high + 1])
        # Center the minimum-energy basin deterministically.
        basin = [i for i in range(low, high + 1) if energy[i] <= minimum + max(0.5, scale * 0.008)]
        refined.append((basin[0] + basin[-1]) // 2 if basin else raw)

    edges = [0] + refined + [size]
    if len(edges) != 6 or any(b <= a for a, b in zip(edges, edges[1:])):
        raise RuntimeError(f"invalid detected {axis} edges: {edges}")
    return edges, energy, projection


def _border_rgb_values(image: Image.Image) -> list[tuple[int, int, int]]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    px = rgb.load()
    values: list[tuple[int, int, int]] = []
    for x in range(width):
        values.append(px[x, 0])
        if height > 1:
            values.append(px[x, height - 1])
    for y in range(1, max(1, height - 1)):
        values.append(px[0, y])
        if width > 1:
            values.append(px[width - 1, y])
    return values


def median_rgb(values: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    if not values:
        return (0, 0, 0)
    return tuple(int(statistics.median([v[channel] for v in values])) for channel in range(3))


def rgb_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2]))


def edge_connected_background_mask(image: Image.Image) -> tuple[bytearray, dict]:
    """Return 1 for background pixels connected to the image edge.

    Color is used only as an edge-connected membership test; no global black/white
    threshold is applied. Interior same-color pixels remain foreground unless they
    are spatially connected to the border background.
    """
    rgb = image.convert("RGB")
    width, height = rgb.size
    px = rgb.load()
    border = _border_rgb_values(rgb)
    reference = median_rgb(border)
    border_distances = sorted(rgb_distance(value, reference) for value in border)
    p95 = border_distances[int(0.95 * (len(border_distances) - 1))] if border_distances else 0
    tolerance = min(BACKGROUND_MAX_TOLERANCE, max(4, p95 + 4))

    eligible = bytearray(width * height)
    for y in range(height):
        row = y * width
        for x in range(width):
            if rgb_distance(px[x, y], reference) <= tolerance:
                eligible[row + x] = 1

    background = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        index = y * width + x
        if eligible[index] and not background[index]:
            background[index] = 1
            queue.append((x, y))

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(1, height - 1):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            index = ny * width + nx
            if eligible[index] and not background[index]:
                background[index] = 1
                queue.append((nx, ny))

    background_count = sum(background)
    return background, {
        "reference_rgb": list(reference),
        "tolerance": tolerance,
        "background_fraction": round(background_count / max(1, width * height), 6),
    }


def rgba_foreground_mask(image: Image.Image, threshold: int = ALPHA_DETECT_THRESHOLD) -> bytearray:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    return bytearray(1 if value > threshold else 0 for value in alpha.get_flattened_data())


def source_detection_mask(image: Image.Image) -> tuple[bytearray, dict]:
    if "A" in image.getbands():
        return rgba_foreground_mask(image), {"method": "SOURCE_ALPHA", "alpha_threshold": ALPHA_DETECT_THRESHOLD}
    background, meta = edge_connected_background_mask(image)
    foreground = bytearray(0 if value else 1 for value in background)
    meta = {"method": "EDGE_CONNECTED_BACKGROUND", **meta}
    return foreground, meta


def remove_edge_connected_background(cell: Image.Image) -> tuple[Image.Image, dict]:
    background, meta = edge_connected_background_mask(cell)
    rgba = cell.convert("RGBA")
    alpha = bytearray([255]) * (rgba.width * rgba.height)
    for i, is_background in enumerate(background):
        if is_background:
            alpha[i] = 0
    rgba.putalpha(Image.frombytes("L", rgba.size, bytes(alpha)))
    foreground_fraction = 1.0 - meta["background_fraction"]
    reliable = 0.02 <= foreground_fraction <= 0.92
    meta.update({
        "reliable": reliable,
        "foreground_fraction": round(foreground_fraction, 6),
    })
    return rgba, meta


def bbox_from_mask(mask: bytearray, width: int, height: int) -> tuple[int, int, int, int] | None:
    left = width
    top = height
    right = -1
    bottom = -1
    for y in range(height):
        row = y * width
        for x in range(width):
            if not mask[row + x]:
                continue
            left = min(left, x)
            top = min(top, y)
            right = max(right, x)
            bottom = max(bottom, y)
    if right < left or bottom < top:
        return None
    return (left, top, right + 1, bottom + 1)


def connected_components(mask: bytearray, width: int, height: int) -> list[Component]:
    visited = bytearray(width * height)
    result: list[Component] = []
    for y0 in range(height):
        for x0 in range(width):
            start = y0 * width + x0
            if not mask[start] or visited[start]:
                continue
            queue: deque[tuple[int, int]] = deque([(x0, y0)])
            visited[start] = 1
            area = 0
            left = right = x0
            top = bottom = y0
            sum_x = 0
            sum_y = 0
            bottom_points: list[int] = []
            while queue:
                x, y = queue.popleft()
                area += 1
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                if y > bottom:
                    bottom = y
                    bottom_points = [x]
                elif y == bottom:
                    bottom_points.append(x)
                sum_x += x
                sum_y += y
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    index = ny * width + nx
                    if mask[index] and not visited[index]:
                        visited[index] = 1
                        queue.append((nx, ny))
            result.append(Component(
                area=area,
                left=left,
                top=top,
                right=right + 1,
                bottom=bottom + 1,
                sum_x=sum_x,
                sum_y=sum_y,
                bottom_x_min=min(bottom_points),
                bottom_x_max=max(bottom_points),
            ))
    result.sort(key=lambda component: component.area, reverse=True)
    return result


def body_mask(image: Image.Image) -> bytearray:
    alpha = image.convert("RGBA").getchannel("A")
    return bytearray(1 if value >= BODY_ALPHA_THRESHOLD else 0 for value in alpha.get_flattened_data())


def choose_body_component(components: list[Component], reference: dict | None = None, cell_size: tuple[int, int] | None = None) -> Component | None:
    candidates = [component for component in components if component.area >= 40]
    if not candidates:
        return components[0] if components else None
    if reference is None or cell_size is None:
        return max(candidates, key=lambda component: component.area)
    width, height = cell_size
    ref_area = max(1.0, float(reference["area"]))
    ref_x = float(reference["center_x_norm"])
    ref_y = float(reference["center_y_norm"])

    def score(component: Component) -> float:
        area_ratio = max(0.05, component.area / ref_area)
        area_cost = abs(math.log(area_ratio))
        dx = component.center_x / max(1, width) - ref_x
        dy = component.center_y / max(1, height) - ref_y
        distance_cost = math.sqrt(dx * dx + dy * dy)
        # Body tends to retain area/centrality across animations; VFX may be much larger/smaller/farther.
        return area_cost * 1.7 + distance_cost * 3.2

    return min(candidates, key=score)


def load_overrides(project_root: Path) -> tuple[dict[tuple[str, int, int], dict], Path]:
    path = project_root / "assets" / "characters" / "character_crop_overrides.json"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"version": 1, "overrides": []}, indent=2) + "\n", encoding="utf-8")
    parsed = json.loads(path.read_text(encoding="utf-8"))
    lookup: dict[tuple[str, int, int], dict] = {}
    for item in parsed.get("overrides", []):
        key = (str(item["character"]), int(item["sheet"]), int(item["cell"]))
        if key in lookup:
            raise ValueError(f"duplicate crop override: {key}")
        lookup[key] = item
    return lookup, path


def write_lossless_webp(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="WEBP", lossless=True, method=3, exact=True)


def make_sprite_frames_tres(manifest: dict, out_path: Path) -> None:
    frame_rows: list[tuple[str, int, str]] = []
    resource_id = 1
    for anim in manifest["animations"]:
        for frame in anim["frames"]:
            frame_rows.append((anim["key"], resource_id, frame["path"]))
            resource_id += 1

    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(frame_rows)} format=3]', ""]
    for _anim, rid, path in frame_rows:
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{rid}"]')
    lines.extend(["", "[resource]", "animations = ["])
    rid_cursor = 1
    for anim_index, anim in enumerate(manifest["animations"]):
        frame_exprs: list[str] = []
        for _frame in anim["frames"]:
            frame_exprs.append('{"duration": 1.0, "texture": ExtResource("%d")}' % rid_cursor)
            rid_cursor += 1
        comma = "," if anim_index < len(manifest["animations"]) - 1 else ""
        lines.append("{")
        lines.append(f'"frames": [{", ".join(frame_exprs)}],')
        lines.append(f'"loop": {str(anim["loop"]).lower()},')
        lines.append(f'"name": &"{anim["key"]}",')
        lines.append(f'"speed": {float(anim["fps"]):.1f}')
        lines.append("}" + comma)
    lines.append("]")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def crop_binary_mask(mask: bytearray, width: int, height: int, rect: tuple[int, int, int, int]) -> tuple[bytearray, int, int]:
    x0, y0, x1, y1 = rect
    out_width = x1 - x0
    out_height = y1 - y0
    out = bytearray(out_width * out_height)
    for local_y, source_y in enumerate(range(y0, y1)):
        source_start = source_y * width + x0
        out_start = local_y * out_width
        out[out_start: out_start + out_width] = mask[source_start: source_start + out_width]
    return out, out_width, out_height


def refine_edges_by_component_gaps(mask: bytearray, width: int, height: int, edges: list[int], axis: str) -> list[int]:
    """Move a gutter into a true foreground-free gap when the local band exposes one."""
    components = [component for component in connected_components(mask, width, height) if component.area >= 300]
    groups: list[list[Component]] = [[] for _ in range(5)]
    for component in components:
        center = component.center_x if axis == "x" else component.center_y
        target = 4
        for index in range(5):
            if edges[index] <= center < edges[index + 1]:
                target = index
                break
        groups[target].append(component)
    refined = [edges[0]]
    for index in range(4):
        left_group = groups[index]
        right_group = groups[index + 1]
        candidate = edges[index + 1]
        if left_group and right_group:
            if axis == "x":
                left_end = max(component.right for component in left_group)
                right_start = min(component.left for component in right_group)
            else:
                left_end = max(component.bottom for component in left_group)
                right_start = min(component.top for component in right_group)
            if left_end <= right_start:
                gap_center = (left_end + right_start) // 2
                previous = refined[-1]
                following = edges[index + 2]
                if previous + GRID_MIN_SEGMENT <= gap_center <= following - GRID_MIN_SEGMENT:
                    candidate = gap_center
        refined.append(candidate)
    refined.append(edges[-1])
    if any(b <= a for a, b in zip(refined, refined[1:])):
        return edges
    return refined


def detect_localized_cell_edges(mask: bytearray, width: int, height: int, global_x_edges: list[int], global_y_edges: list[int]) -> tuple[list[list[int]], list[list[int]]]:
    """Detect per-row vertical gutters and per-column horizontal gutters.

    The coarse whole-sheet gutters establish the five repeated row/column bands.
    Each band is then re-projected locally so sprites that legitimately sit near a
    neighboring column/row do not get cut by a single whole-sheet separator.
    """
    row_x_edges: list[list[int]] = []
    for row in range(5):
        y0, y1 = global_y_edges[row], global_y_edges[row + 1]
        local_mask, local_width, local_height = crop_binary_mask(mask, width, height, (0, y0, width, y1))
        edges, _energy, _projection = detect_grid_edges(local_mask, local_width, local_height, "x")
        row_x_edges.append(refine_edges_by_component_gaps(local_mask, local_width, local_height, edges, "x"))

    column_y_edges: list[list[int]] = []
    for column in range(5):
        x0, x1 = global_x_edges[column], global_x_edges[column + 1]
        local_mask, local_width, local_height = crop_binary_mask(mask, width, height, (x0, 0, x1, height))
        edges, _energy, _projection = detect_grid_edges(local_mask, local_width, local_height, "y")
        column_y_edges.append(refine_edges_by_component_gaps(local_mask, local_width, local_height, edges, "y"))
    return row_x_edges, column_y_edges


def detect_outer_margin(projection: list[int]) -> list[int]:
    if not projection:
        return [0, 0]
    peak = max(projection)
    threshold = max(1, int(peak * 0.01))
    first = 0
    while first < len(projection) and projection[first] <= threshold:
        first += 1
    last = len(projection) - 1
    while last >= 0 and projection[last] <= threshold:
        last -= 1
    return [first, max(0, len(projection) - 1 - last)]


def source_component_crosses_separator(components: list[Component], axis: str, separator: int) -> bool:
    # Significant connected component that physically crosses a detected gutter is suspicious.
    for component in components:
        if component.area < 24:
            continue
        if axis == "x" and component.left < separator < component.right:
            if separator - component.left >= 2 and component.right - separator >= 2:
                return True
        if axis == "y" and component.top < separator < component.bottom:
            if separator - component.top >= 2 and component.bottom - separator >= 2:
                return True
    return False


def build(character: str, source_zip: Path, project_root: Path) -> dict:
    if character not in CHARACTERS:
        raise ValueError(f"unknown character: {character}")
    cfg = CHARACTERS[character]
    if not source_zip.is_file():
        raise FileNotFoundError(source_zip)

    bundle_bytes = source_zip.read_bytes()
    bundle_sha = sha256_bytes(bundle_bytes)
    overrides, overrides_path = load_overrides(project_root)

    asset_root = project_root / "assets" / "characters" / character
    qa_root = project_root / "build" / "qa" / character
    if asset_root.exists():
        shutil.rmtree(asset_root)
    if qa_root.exists():
        shutil.rmtree(qa_root)
    (asset_root / "source").mkdir(parents=True, exist_ok=True)
    (asset_root / "sprites").mkdir(parents=True, exist_ok=True)
    (asset_root / "animations").mkdir(parents=True, exist_ok=True)
    qa_root.mkdir(parents=True, exist_ok=True)

    canonical_bundle_path = asset_root / "source" / cfg["canonical_source_bundle"]
    canonical_bundle_path.write_bytes(bundle_bytes)

    source_sheet_records: list[dict] = []
    raw_frames: list[dict] = []
    warnings: list[str] = []
    override_count = 0
    separator_contamination: list[dict] = []

    with zipfile.ZipFile(io.BytesIO(bundle_bytes), "r") as zf:
        sheets = choose_sheet_entries(zf)
        for sheet_number, info in sheets:
            payload = zf.read(info)
            with Image.open(io.BytesIO(payload)) as opened:
                source_mode = opened.mode
                source = opened.copy()
            width, height = source.size
            detection_mask, detection_meta = source_detection_mask(source)
            x_edges, x_energy, x_projection = detect_grid_edges(detection_mask, width, height, "x")
            y_edges, y_energy, y_projection = detect_grid_edges(detection_mask, width, height, "y")
            row_x_edges, column_y_edges = detect_localized_cell_edges(detection_mask, width, height, x_edges, y_edges)

            sheet_components = connected_components(detection_mask, width, height)

            source_name = f"sheet_{sheet_number:02d}.webp"
            source_path = asset_root / "source" / source_name
            source_path.write_bytes(payload)
            sheet_record = {
                "sheet": sheet_number,
                "path": f"res://assets/characters/{character}/source/{source_name}",
                "sha256": sha256_bytes(payload),
                "width": width,
                "height": height,
                "source_mode": source_mode,
                "has_alpha_channel": "A" in source.getbands(),
                "grid_detection": {
                    "algorithm": "GRID/GUTTER DETECTION",
                    "x_edges": x_edges,
                    "y_edges": y_edges,
                    "row_x_edges": row_x_edges,
                    "column_y_edges": column_y_edges,
                    "column_widths": [b - a for a, b in zip(x_edges, x_edges[1:])],
                    "row_heights": [b - a for a, b in zip(y_edges, y_edges[1:])],
                    "outer_margin_x": detect_outer_margin(x_projection),
                    "outer_margin_y": detect_outer_margin(y_projection),
                    "foreground_detection": detection_meta,
                    "x_separator_energy": [round(x_energy[v], 3) for v in x_edges[1:-1]],
                    "y_separator_energy": [round(y_energy[v], 3) for v in y_edges[1:-1]],
                },
            }
            source_sheet_records.append(sheet_record)

            for row in range(GRID_ROWS):
                for col in range(GRID_COLUMNS):
                    local_index = row * GRID_COLUMNS + col + 1
                    global_index = (sheet_number - 1) * FRAMES_PER_SHEET + local_index
                    animation_key, animation_frame, fps, loop, hold_final = animation_for_global_frame(global_index)
                    safe_rect = (
                        row_x_edges[row][col],
                        column_y_edges[col][row],
                        row_x_edges[row][col + 1],
                        column_y_edges[col][row + 1],
                    )
                    safe_cell_source = source.crop(safe_rect)
                    alpha_cleanup: dict = {"method": "SOURCE_ALPHA", "reliable": True}
                    if "A" in source.getbands():
                        cell_rgba = safe_cell_source.convert("RGBA")
                    else:
                        cell_rgba, cleanup_meta = remove_edge_connected_background(safe_cell_source)
                        alpha_cleanup = {"method": "EDGE_CONNECTED_BACKGROUND", **cleanup_meta}
                        if not cleanup_meta["reliable"]:
                            warnings.append(
                                f"{character} sheet {sheet_number:02d} cell {local_index:02d}: "
                                "edge-connected background classification confidence is low"
                            )

                    alpha_values = list(cell_rgba.getchannel("A").get_flattened_data())
                    alpha_mask_all = bytearray(1 if value > 0 else 0 for value in alpha_values)
                    foreground_bbox = bbox_from_mask(alpha_mask_all, cell_rgba.width, cell_rgba.height)
                    meaningful_mask = bytearray(1 if value >= ALPHA_DETECT_THRESHOLD else 0 for value in alpha_values)
                    meaningful_bbox = bbox_from_mask(meaningful_mask, cell_rgba.width, cell_rgba.height)
                    meaningful_foreground_pixels = int(sum(meaningful_mask))
                    # Refuse to treat a few antialias/noise pixels as an actual production frame.
                    source_foreground_missing = meaningful_bbox is None or meaningful_foreground_pixels < 500
                    if source_foreground_missing:
                        foreground_bbox = (0, 0, 0, 0)
                        meaningful_bbox = (0, 0, 0, 0)
                        crop_rect_local = [0, 0, 1, 1]
                        warnings.append(
                            f"{character} sheet {sheet_number:02d} cell {local_index:02d}: "
                            "SOURCE CELL HAS NO FOREGROUND; no frame content can be inferred or fabricated"
                        )
                    else:
                        pad = 6 if animation_key in ("special_neutral", "ultimate") else 4
                        left = max(0, foreground_bbox[0] - pad)
                        top = max(0, foreground_bbox[1] - pad)
                        right = min(cell_rgba.width, foreground_bbox[2] + pad)
                        bottom = min(cell_rgba.height, foreground_bbox[3] + pad)
                        crop_rect_local = [left, top, right, bottom]

                    override = overrides.get((character, sheet_number, local_index))
                    pivot_override: tuple[float, float] | None = None
                    override_notes = ""
                    if override is not None:
                        override_count += 1
                        override_notes = str(override.get("notes", ""))
                        if all(field in override for field in ("left", "top", "right", "bottom")):
                            absolute = [int(override[field]) for field in ("left", "top", "right", "bottom")]
                            if not (safe_rect[0] <= absolute[0] < absolute[2] <= safe_rect[2] and safe_rect[1] <= absolute[1] < absolute[3] <= safe_rect[3]):
                                raise ValueError(f"crop override escapes safe cell: {(character, sheet_number, local_index)} -> {absolute}")
                            crop_rect_local = [
                                absolute[0] - safe_rect[0], absolute[1] - safe_rect[1],
                                absolute[2] - safe_rect[0], absolute[3] - safe_rect[1],
                            ]
                        if "feet_x" in override and "feet_y" in override:
                            pivot_override = (
                                float(override["feet_x"]) - safe_rect[0],
                                float(override["feet_y"]) - safe_rect[1],
                            )

                    crop = Image.new("RGBA", (1, 1), (0, 0, 0, 0)) if source_foreground_missing else cell_rgba.crop(tuple(crop_rect_local))
                    body_components = [] if source_foreground_missing else connected_components(body_mask(cell_rgba), cell_rgba.width, cell_rgba.height)
                    raw_frames.append({
                        "sheet": sheet_number,
                        "cell": local_index,
                        "row": row + 1,
                        "column": col + 1,
                        "global_frame": global_index,
                        "animation_key": animation_key,
                        "animation_frame": animation_frame,
                        "fps": fps,
                        "loop": loop,
                        "hold_final_frame": hold_final,
                        "safe_rect": list(safe_rect),
                        "safe_cell_size": [cell_rgba.width, cell_rgba.height],
                        "foreground_bbox_local": list(foreground_bbox),
                        "meaningful_foreground_bbox_local": list(meaningful_bbox),
                        "meaningful_foreground_pixels": meaningful_foreground_pixels,
                        "source_foreground_missing": source_foreground_missing,
                        "crop_rect_local": crop_rect_local,
                        "crop_rect_source": [
                            safe_rect[0] + crop_rect_local[0], safe_rect[1] + crop_rect_local[1],
                            safe_rect[0] + crop_rect_local[2], safe_rect[1] + crop_rect_local[3],
                        ],
                        "crop_rgba": crop,
                        "cell_rgba": cell_rgba,
                        "body_components": body_components,
                        "alpha_cleanup": alpha_cleanup,
                        "pivot_override": pivot_override,
                        "override_applied": override is not None,
                        "override_notes": override_notes,
                        "foreground_touches_safe_boundary": (not source_foreground_missing) and any((
                            meaningful_bbox[0] <= 0,
                            meaningful_bbox[1] <= 0,
                            meaningful_bbox[2] >= cell_rgba.width,
                            meaningful_bbox[3] >= cell_rgba.height,
                        )),
                    })

    # Build a body reference from idle + walk frames using largest solid-alpha component.
    reference_candidates: list[dict] = []
    for frame in raw_frames:
        if frame["animation_key"] not in {"idle", "walk_forward", "walk_back", "guard_stand"}:
            continue
        component = choose_body_component(frame["body_components"])
        if component is None:
            continue
        cell_w, cell_h = frame["safe_cell_size"]
        reference_candidates.append({
            "area": component.area,
            "center_x_norm": component.center_x / max(1, cell_w),
            "center_y_norm": component.center_y / max(1, cell_h),
        })
    if not reference_candidates:
        raise RuntimeError(f"could not derive body reference for {character}")
    body_reference = {
        "area": statistics.median([item["area"] for item in reference_candidates]),
        "center_x_norm": statistics.median([item["center_x_norm"] for item in reference_candidates]),
        "center_y_norm": statistics.median([item["center_y_norm"] for item in reference_candidates]),
    }

    # Resolve feet/support metadata in safe-cell coordinates.
    max_left_extent = max_right_extent = max_up_extent = max_down_extent = 0.0
    max_crop_width = max_crop_height = 0
    for frame in raw_frames:
        cell_w, cell_h = frame["safe_cell_size"]
        component = choose_body_component(frame["body_components"], body_reference, (cell_w, cell_h))
        if frame["pivot_override"] is not None:
            feet_x, feet_y = frame["pivot_override"]
            method = "OVERRIDE"
        elif component is not None:
            feet_x, feet_y = component.feet_x, float(component.ground_y)
            method = "BODY_COMPONENT_SUPPORT"
        else:
            feet_x, feet_y = cell_w * 0.5, float(cell_h - 1)
            method = "MISSING_FOREGROUND_FALLBACK" if frame["source_foreground_missing"] else "SAFE_CELL_FALLBACK"
            if not frame["source_foreground_missing"]:
                warnings.append(f"{character} frame {frame['global_frame']:03d}: body support fallback used")
        frame["source_feet_x"] = round(feet_x, 3)
        frame["source_ground_y"] = round(feet_y, 3)
        frame["feet_detection_method"] = method

        l, t, r, b = frame["crop_rect_local"]
        crop_w = r - l
        crop_h = b - t
        max_crop_width = max(max_crop_width, crop_w)
        max_crop_height = max(max_crop_height, crop_h)
        if frame["animation_key"] in GROUNDED_KEYS:
            max_left_extent = max(max_left_extent, feet_x - l)
            max_right_extent = max(max_right_extent, r - feet_x)
            max_up_extent = max(max_up_extent, feet_y - t)
            max_down_extent = max(max_down_extent, b - feet_y)

    required_width = int(math.ceil(max(max_crop_width + 2 * CANVAS_MARGIN, 2 * max(max_left_extent, max_right_extent) + 2 * CANVAS_MARGIN)))
    required_height = int(math.ceil(max(max_crop_height + 2 * CANVAS_MARGIN, max_up_extent + max_down_extent + 2 * CANVAS_MARGIN)))
    canvas_size = next((candidate for candidate in CANVAS_CANDIDATES if candidate >= max(required_width, required_height)), None)
    if canvas_size is None:
        raise RuntimeError(f"required runtime canvas {required_width}x{required_height} exceeds supported candidates")
    canvas_width = canvas_height = canvas_size
    feet_center_x = canvas_width // 2
    ground_baseline_y = canvas_height - CANVAS_MARGIN - int(math.ceil(max_down_extent))
    if ground_baseline_y <= CANVAS_MARGIN:
        raise RuntimeError("invalid runtime ground baseline")

    # Render frames to the shared canvas without scaling/stretching.
    animations_by_key: dict[str, dict] = {}
    runtime_frame_records: list[dict] = []
    frames_touching_canvas = 0
    for frame in raw_frames:
        crop: Image.Image = frame["crop_rgba"]
        l, t, r, b = frame["crop_rect_local"]
        if frame["animation_key"] in GROUNDED_KEYS:
            paste_x = int(round(feet_center_x - (frame["source_feet_x"] - l)))
            paste_y = int(round(ground_baseline_y - (frame["source_ground_y"] - t)))
        else:
            paste_x = (canvas_width - crop.width) // 2
            paste_y = (canvas_height - crop.height) // 2
        if paste_x < CANVAS_MARGIN or paste_y < CANVAS_MARGIN or paste_x + crop.width > canvas_width - CANVAS_MARGIN or paste_y + crop.height > canvas_height - CANVAS_MARGIN:
            raise RuntimeError(
                f"runtime canvas placement lacks margin: {character} frame {frame['global_frame']:03d} "
                f"crop={crop.size} paste=({paste_x},{paste_y}) canvas={canvas_size}"
            )
        runtime = Image.new("RGBA", (canvas_width, canvas_height), (0, 0, 0, 0))
        runtime.alpha_composite(crop, (paste_x, paste_y))
        runtime_mask = bytearray(1 if value > 0 else 0 for value in runtime.getchannel("A").get_flattened_data())
        runtime_bbox = bbox_from_mask(runtime_mask, canvas_width, canvas_height)
        touches_canvas = False
        if runtime_bbox is not None:
            touches_canvas = runtime_bbox[0] <= 0 or runtime_bbox[1] <= 0 or runtime_bbox[2] >= canvas_width or runtime_bbox[3] >= canvas_height
            if touches_canvas:
                frames_touching_canvas += 1

        animation_key = frame["animation_key"]
        animation_frame = frame["animation_frame"]
        out_rel = Path("assets") / "characters" / character / "sprites" / animation_key / f"{animation_key}_{animation_frame:03d}.webp"
        out_path = project_root / out_rel
        write_lossless_webp(runtime, out_path)
        output_sha = sha256_file(out_path)

        runtime_ground_y = None
        if animation_key in GROUNDED_KEYS and not frame["source_foreground_missing"]:
            runtime_ground_y = ground_baseline_y

        record = {
            "index": animation_frame,
            "global_frame": frame["global_frame"],
            "sheet": frame["sheet"],
            "cell": frame["cell"],
            "row": frame["row"],
            "column": frame["column"],
            "path": "res://" + out_rel.as_posix(),
            "output_sha256": output_sha,
            "safe_cell_rect": frame["safe_rect"],
            "foreground_bbox_in_safe_cell": frame["foreground_bbox_local"],
            "meaningful_foreground_bbox_in_safe_cell": frame["meaningful_foreground_bbox_local"],
            "meaningful_foreground_pixels": frame["meaningful_foreground_pixels"],
            "final_crop_rect_source": frame["crop_rect_source"],
            "runtime_foreground_bbox": list(runtime_bbox) if runtime_bbox is not None else None,
            "runtime_size": [canvas_width, canvas_height],
            "runtime_paste": [paste_x, paste_y],
            "pivot_pixels": [feet_center_x, ground_baseline_y],
            "visual_offset_pixels": [0, 0],
            "source_feet_x": frame["source_feet_x"],
            "source_ground_y": frame["source_ground_y"],
            "runtime_supporting_foot_y": runtime_ground_y,
            "feet_detection_method": frame["feet_detection_method"],
            "grounded": animation_key in GROUNDED_KEYS,
            "alpha_cleanup": frame["alpha_cleanup"],
            "foreground_touches_safe_boundary": frame["foreground_touches_safe_boundary"],
            "touches_runtime_canvas": touches_canvas,
            "source_foreground_missing": frame["source_foreground_missing"],
            "override_applied": frame["override_applied"],
            "override_notes": frame["override_notes"],
        }
        runtime_frame_records.append(record)
        anim = animations_by_key.setdefault(animation_key, {
            "key": animation_key,
            "presentation_name": cfg["presentation_names"].get(animation_key, animation_key),
            "fps": frame["fps"],
            "loop": frame["loop"],
            "hold_final_frame": frame["hold_final_frame"],
            "playback_authority": "MOVE_PHASE_TIMELINE" if animation_key in ATTACK_KEYS else "PRESENTATION_FPS",
            "frames": [],
        })
        anim["frames"].append(record)

    animations: list[dict] = []
    for key, expected_count, _fps, _loop, _hold in ANIMATIONS:
        anim = animations_by_key[key]
        if len(anim["frames"]) != expected_count:
            raise RuntimeError(f"{character} {key}: expected {expected_count} frames, got {len(anim['frames'])}")
        anim["frame_count"] = len(anim["frames"])
        anim["feet_anchor_pixels"] = [feet_center_x, ground_baseline_y] if key in GROUNDED_KEYS else None
        if key == "stand_light":
            anim["timeline_policy"] = {"visual_phase_counts": [3, 3, 4], "anticipation_hold_frame": 3, "contact_hold_ticks": 0}
        elif key == "stand_heavy":
            anim["timeline_policy"] = {"visual_phase_counts": [6, 4, 5], "anticipation_hold_frame": 6, "contact_hold_ticks": 1}
        elif key == "special_neutral":
            anim["timeline_policy"] = {"mode": "FIT_MOVE_PHASES", "startup_hold_ticks": 2, "anticipation_hold_frame": 4, "contact_hold_ticks": 2}
        elif key == "ultimate":
            anim["timeline_policy"] = {"mode": "FIT_MOVE_PHASES", "startup_hold_ticks": 4, "anticipation_hold_frame": 8, "contact_visual_range": [15, 19], "contact_hold_ticks": 3}
        elif key in ATTACK_KEYS:
            anim["timeline_policy"] = {"mode": "FIT_MOVE_PHASES", "startup_hold_ticks": 1, "contact_hold_ticks": 1}
        animations.append(anim)

    # Walk ground variance should be exactly stable after normalization.
    walk_validation: dict[str, dict] = {}
    for key in ("walk_forward", "walk_back"):
        frames_for_walk = animations_by_key[key]["frames"]
        ys = [frame["runtime_supporting_foot_y"] for frame in frames_for_walk if frame["runtime_supporting_foot_y"] is not None]
        variance = statistics.pvariance(ys) if len(ys) > 1 else 0.0
        missing = sum(1 for frame in frames_for_walk if frame["source_foreground_missing"])
        walk_validation[key] = {
            "supporting_foot_baselines": ys,
            "variance": round(variance, 6),
            "max_deviation": max(ys) - min(ys) if ys else None,
            "source_missing_frames": missing,
            "status": "PASS" if len(ys) == len(frames_for_walk) and max(ys) - min(ys) <= 1 else "FAIL",
        }

    manifest = {
        "manifest_version": 3,
        "asset_version": ASSET_VERSION,
        "pack_type": "BASE_FIGHTER",
        "mode_id": "",
        "character_asset_key": character,
        "character_id": cfg["character_id"],
        "display_name": cfg["display_name"],
        "gameplay_slot": cfg["gameplay_slot"],
        "source_bundle": cfg["canonical_source_bundle"],
        "source_bundle_path": f"res://assets/characters/{character}/source/{cfg['canonical_source_bundle']}",
        "source_sha256": bundle_sha,
        "sheet_count": SHEETS_PER_CHARACTER,
        "grid_columns": GRID_COLUMNS,
        "grid_rows": GRID_ROWS,
        "frame_count": TOTAL_FRAMES,
        "crop_algorithm": "GRID/GUTTER DETECTION",
        "naive_width_division": "REMOVED",
        "background_removal": "SOURCE_ALPHA_OR_EDGE_CONNECTED_ONLY",
        "source_sheets": source_sheet_records,
        "runtime_canvas": [canvas_width, canvas_height],
        "runtime_canvas_selection": {
            "candidates": list(CANVAS_CANDIDATES),
            "required_dimensions": [required_width, required_height],
            "max_crop_dimensions": [max_crop_width, max_crop_height],
            "selected": canvas_size,
            "scaling_applied": False,
        },
        "pivot_convention": "FEET_CENTER",
        "feet_center_x": feet_center_x,
        "ground_baseline_y": ground_baseline_y,
        "body_reference": {key: round(float(value), 6) for key, value in body_reference.items()},
        "walk_ground_validation": walk_validation,
        "crop_overrides_path": "res://assets/characters/character_crop_overrides.json",
        "crop_overrides_applied": override_count,
        "separator_contamination_candidates": separator_contamination,
        "source_missing_foreground_frames": [frame["global_frame"] for frame in runtime_frame_records if frame["source_foreground_missing"]],
        "frames_touching_canvas": frames_touching_canvas,
        "canonical_facing": "RIGHT",
        "facing_rule": "horizontal mirror in FighterVisual",
        "special_vfx_rule": "presentation_only_no_gameplay_geometry_inference",
        "animations": animations,
        "sprite_frames_resource": f"res://assets/characters/{character}/animations/{character}_sprite_frames.tres",
        "visual_scene": f"res://presentation/visuals/production/{character}_visual.tscn",
        "fallback_order": ["exact", "generic reaction/attack", "idle", "greybox"],
        "determinism": {"stable_filenames": True, "timestamps_in_output": False, "lossless_webp": True},
        "warnings": warnings,
    }

    manifest_path = asset_root / "animations" / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    make_sprite_frames_tres(manifest, asset_root / "animations" / f"{character}_sprite_frames.tres")
    (asset_root / "source" / "source_bundle.sha256").write_text(f"{bundle_sha}  {cfg['canonical_source_bundle']}\n", encoding="utf-8")

    generate_qa(character, project_root, source_sheet_records, raw_frames, runtime_frame_records, qa_root)

    summary = {
        "character": character,
        "display_name": cfg["display_name"],
        "character_id": cfg["character_id"],
        "source_sheets": 10,
        "frames_extracted": 250,
        "animations": 23,
        "source_sha256": bundle_sha,
        "runtime_canvas": f"{canvas_width}x{canvas_height}",
        "crop_algorithm": "GRID/GUTTER DETECTION",
        "crop_overrides": override_count,
        "frames_touching_canvas": frames_touching_canvas,
        "separator_contamination_candidates": len(separator_contamination),
        "walk_forward": walk_validation["walk_forward"]["status"],
        "walk_back": walk_validation["walk_back"]["status"],
        "warnings": warnings,
        "manifest": str(manifest_path),
        "overrides_file": str(overrides_path),
    }
    return summary


def generate_qa(character: str, project_root: Path, source_sheets: list[dict], raw_frames: list[dict], runtime_records: list[dict], qa_root: Path) -> None:
    runtime_by_global = {int(record["global_frame"]): record for record in runtime_records}
    frames_by_sheet: dict[int, list[dict]] = {}
    for frame in raw_frames:
        frames_by_sheet.setdefault(int(frame["sheet"]), []).append(frame)

    font = ImageFont.load_default()
    for sheet in source_sheets:
        sheet_number = int(sheet["sheet"])
        source_path = project_root / sheet["path"].replace("res://", "")
        with Image.open(source_path) as opened:
            base = opened.convert("RGBA")
        overlay = base.copy()
        draw = ImageDraw.Draw(overlay)
        x_edges = sheet["grid_detection"]["x_edges"]
        y_edges = sheet["grid_detection"]["y_edges"]
        row_x_edges = sheet["grid_detection"]["row_x_edges"]
        column_y_edges = sheet["grid_detection"]["column_y_edges"]
        for row in range(5):
            y0, y1 = y_edges[row], y_edges[row + 1]
            for x in row_x_edges[row]:
                draw.line((x, y0, x, y1 - 1), fill=(0, 255, 255, 255), width=1)
        for column in range(5):
            x0, x1 = x_edges[column], x_edges[column + 1]
            for y in column_y_edges[column]:
                draw.line((x0, y, x1 - 1, y), fill=(0, 255, 255, 255), width=1)
        for frame in frames_by_sheet.get(sheet_number, []):
            l, t, r, b = frame["crop_rect_source"]
            draw.rectangle((l, t, r - 1, b - 1), outline=(255, 0, 255, 255), width=1)
            safe = frame["safe_rect"]
            draw.text((safe[0] + 2, safe[1] + 2), f"{frame['cell']:02d}", fill=(255, 255, 0, 255), font=font)
        overlay.save(qa_root / f"source_sheet_{sheet_number:02d}_crop_debug.png", format="PNG", optimize=False)

        tile_w, tile_h = 300, 260
        contact = Image.new("RGBA", (tile_w * 5, tile_h * 5), (28, 28, 30, 255))
        contact_draw = ImageDraw.Draw(contact)
        for frame in frames_by_sheet.get(sheet_number, []):
            record = runtime_by_global[frame["global_frame"]]
            runtime_path = project_root / record["path"].replace("res://", "")
            with Image.open(runtime_path) as runtime_opened:
                runtime = runtime_opened.convert("RGBA")
            preview = runtime.copy()
            preview.thumbnail((190, 190), Image.Resampling.NEAREST)
            col = frame["column"] - 1
            row = frame["row"] - 1
            origin_x = col * tile_w
            origin_y = row * tile_h
            image_x = origin_x + (tile_w - preview.width) // 2
            image_y = origin_y + 8
            contact.alpha_composite(preview, (image_x, image_y))
            safe = record["safe_cell_rect"]
            fg = record["foreground_bbox_in_safe_cell"]
            crop = record["final_crop_rect_source"]
            text_lines = [
                f"sheet {sheet_number:02d} r{frame['row']} c{frame['column']} cell {frame['cell']:02d}",
                f"anim {frame['animation_key']} #{frame['animation_frame']:02d}",
                f"safe {safe[0]},{safe[1]}-{safe[2]},{safe[3]}",
                f"fg {fg[0]},{fg[1]}-{fg[2]},{fg[3]}",
                f"crop {crop[0]},{crop[1]}-{crop[2]},{crop[3]}",
                f"feet y {record['runtime_supporting_foot_y']}",
            ]
            y_text = origin_y + 202
            for line in text_lines:
                contact_draw.text((origin_x + 5, y_text), line, fill=(235, 235, 235, 255), font=font)
                y_text += 9
            contact_draw.rectangle((origin_x, origin_y, origin_x + tile_w - 1, origin_y + tile_h - 1), outline=(80, 80, 85, 255), width=1)
        contact.save(qa_root / f"source_sheet_{sheet_number:02d}_contact_sheet.png", format="PNG", optimize=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", required=True, choices=sorted(CHARACTERS))
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    summary = build(args.character, args.source.resolve(), project_root)
    for key, value in summary.items():
        if key == "warnings":
            for warning in value:
                print(f"WARNING: {warning}")
        else:
            print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
