# Generic presentation-only rectangular effect/hazard visual.
class_name ProductionWorldEffectVisual
extends Node2D

@export var sprite_frames: SpriteFrames
@export_file("*.json") var manifest_path: String = ""
@export var animation_key: StringName = &"effect"
@export var autoplay: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _frame_meta: Array = []
var _configured_scale: float = 1.0
var _facing: int = 1

func _ready() -> void:
    if sprite_frames != null:
        sprite.sprite_frames = sprite_frames
    sprite.centered = false
    _load_manifest()
    if not sprite.frame_changed.is_connected(_update_frame_pivot):
        sprite.frame_changed.connect(_update_frame_pivot)
    if autoplay and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_key):
        sprite.play(animation_key)
    _update_frame_pivot()

# Kept compatible with ProjectileVisualPresenter's existing scene contract.
func configure(_asset_id: StringName, _placeholder_color: Color = Color.WHITE, visual_scale: float = 1.0) -> void:
    _configured_scale = maxf(0.001, visual_scale)
    _apply_facing_scale()

func set_facing(value: int) -> void:
    _facing = -1 if value < 0 else 1
    _apply_facing_scale()

func set_effect_visible(value: bool) -> void:
    visible = value

func _apply_facing_scale() -> void:
    scale = Vector2(_configured_scale * float(_facing), _configured_scale)

func _load_manifest() -> void:
    _frame_meta.clear()
    if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not (parsed is Dictionary):
        return
    var frames: Variant = parsed.get("frames", [])
    if frames is Array:
        _frame_meta = frames

func _update_frame_pivot() -> void:
    if sprite == null or _frame_meta.is_empty():
        return
    var index := clampi(sprite.frame, 0, _frame_meta.size() - 1)
    var meta: Variant = _frame_meta[index]
    if not (meta is Dictionary):
        return
    var pivot: Variant = meta.get("pivot_pixels", [])
    if pivot is Array and pivot.size() == 2:
        sprite.position = Vector2(-float(pivot[0]), -float(pivot[1]))
