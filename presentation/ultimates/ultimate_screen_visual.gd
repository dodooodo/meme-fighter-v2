# Generic screen-space pack visual. Reads presentation manifest only.
# It never pauses or advances BattleSimulation.
class_name UltimateScreenVisual
extends Control

@export_file("*.json") var manifest_path: String = ""
@onready var texture_rect: TextureRect = $TextureRect

var _frames: Array[Texture2D] = []
var _fps: float = 1.0
var _loop: bool = false
var _elapsed: float = 0.0
var _frame_index: int = 0

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _load_manifest()
    _apply_frame()

func _process(delta: float) -> void:
    if _frames.size() <= 1 or _fps <= 0.0:
        return
    _elapsed += delta
    var wanted := int(floor(_elapsed * _fps))
    if _loop:
        wanted %= _frames.size()
    else:
        wanted = mini(wanted, _frames.size() - 1)
    if wanted != _frame_index:
        _frame_index = wanted
        _apply_frame()

func _load_manifest() -> void:
    _frames.clear()
    if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not (parsed is Dictionary):
        return
    _fps = float(parsed.get("fps", 1.0))
    _loop = bool(parsed.get("loop", false))
    for frame: Variant in parsed.get("frames", []):
        if not (frame is Dictionary):
            continue
        var path := String(frame.get("path", ""))
        if path.is_empty():
            continue
        var texture := load(path) as Texture2D
        if texture != null:
            _frames.append(texture)

func _apply_frame() -> void:
    if texture_rect == null:
        return
    texture_rect.texture = _frames[_frame_index] if _frame_index >= 0 and _frame_index < _frames.size() else null
