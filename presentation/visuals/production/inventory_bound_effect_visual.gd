# Presentation-only renderer for one exact ProductionAnimationBinding.
# Detached effect/summon/hazard/projectile visuals never own gameplay timing or collision.
class_name InventoryBoundEffectVisual
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
var binding: ProductionAnimationBinding = null
var _frame_index: int = 0
var _elapsed: float = 0.0
var _facing: int = 1
var _scale_value: float = 1.0

func configure_binding(value: ProductionAnimationBinding, facing: int = 1, visual_scale: float = 1.0) -> void:
    binding = value
    _frame_index = 0
    _elapsed = 0.0
    _facing = -1 if facing < 0 else 1
    _scale_value = maxf(0.001, visual_scale)
    _apply_scale()
    _apply_frame()

func configure(_asset_id: StringName, _placeholder_color: Color = Color.WHITE, visual_scale: float = 1.0) -> void:
    _scale_value = maxf(0.001, visual_scale)
    _apply_scale()

func set_facing(value: int) -> void:
    _facing = -1 if value < 0 else 1
    _apply_scale()

func _process(delta: float) -> void:
    if binding == null or binding.frame_paths.size() <= 1:
        return
    # Presentation cadence only. Gameplay lifetime/active frames remain authoritative elsewhere.
    _elapsed += delta
    var wanted := int(floor(_elapsed * 8.0))
    if binding.loop or binding.hold_policy == ProductionAnimationBinding.HoldPolicy.LOOP:
        wanted %= binding.frame_paths.size()
    else:
        wanted = mini(wanted, binding.frame_paths.size() - 1)
    if wanted != _frame_index:
        _frame_index = wanted
        _apply_frame()

func _apply_scale() -> void:
    scale = Vector2(float(_facing) * _scale_value, _scale_value)

func _apply_frame() -> void:
    if sprite == null:
        return
    if binding == null or binding.frame_paths.is_empty():
        sprite.texture = null
        return
    _frame_index = clampi(_frame_index, 0, binding.frame_paths.size() - 1)
    var texture := load(binding.frame_paths[_frame_index]) as Texture2D
    sprite.texture = texture
    sprite.centered = true
    sprite.position = Vector2.ZERO
