# Presentation-side visual adapter. Local origin convention is feet center.
class_name FighterVisual
extends Node2D

var current_animation_key: StringName = &"idle"
var current_facing: int = 1
var presentation_data: CharacterPresentationData
var visual_scale_multiplier: float = 1.0

func set_character_presentation_data(data: CharacterPresentationData) -> void:
    presentation_data = data
    _apply_presentation_scale()

func set_visual_scale_multiplier(value: float) -> void:
    visual_scale_multiplier = maxf(0.001, value)
    _apply_presentation_scale()

func play_animation(animation_key: StringName) -> void:
    current_animation_key = animation_key if animation_key != &"" else &"idle"

func set_screen_position(screen_position: Vector2) -> void:
    position = screen_position

func set_facing(facing: int) -> void:
    current_facing = -1 if facing < 0 else 1
    _apply_presentation_scale()

func set_visual_visible(value: bool) -> void:
    visible = value

func socket_world_position(socket_id: int, custom_offset: Vector2 = Vector2.ZERO) -> Vector2:
    var socket_key := _socket_key(socket_id)
    var local_offset := Vector2.ZERO
    if presentation_data != null and presentation_data.socket_offsets.has(socket_key):
        var stored: Variant = presentation_data.socket_offsets[socket_key]
        if stored is Vector2:
            local_offset = stored
    return to_global(local_offset + custom_offset)

func _socket_key(socket_id: int) -> StringName:
    match socket_id:
        EffectPresentationBinding.AnchorSocket.BODY_CENTER:
            return &"BODY_CENTER"
        EffectPresentationBinding.AnchorSocket.HEAD:
            return &"HEAD"
        EffectPresentationBinding.AnchorSocket.MOUTH:
            return &"MOUTH"
        EffectPresentationBinding.AnchorSocket.LEFT_HAND:
            return &"LEFT_HAND"
        EffectPresentationBinding.AnchorSocket.RIGHT_HAND:
            return &"RIGHT_HAND"
        EffectPresentationBinding.AnchorSocket.WEAPON:
            return &"WEAPON"
        EffectPresentationBinding.AnchorSocket.CUSTOM_OFFSET:
            return &"CUSTOM_OFFSET"
        _:
            return &"FEET_CENTER"

func _apply_presentation_scale() -> void:
    var base_scale := presentation_data.visual_scale if presentation_data != null else 1.0
    var final_scale := base_scale * visual_scale_multiplier
    scale = Vector2(final_scale * float(current_facing), final_scale)

# Read-only gameplay phase facts may be mirrored into presentation. Implementations
# must never use animation completion to mutate or end gameplay moves.
func sync_move_timeline(_move_id: StringName, _move_frame: int, _startup_frames: int, _active_frames: int, _recovery_frames: int) -> void:
    pass

# Rendering-only emphasis. Simulation keeps advancing normally.
func request_visual_hold(_render_ticks: int) -> void:
    pass

func request_hit_flash(_strength: float, _render_ticks: int) -> void:
    pass

# Preview-only controls; battle runtime leaves preview_mode disabled.
func set_preview_mode(_enabled: bool, _speed_scale: float = 1.0) -> void:
    pass

func debug_frame_number() -> int:
    return 1

func debug_presentation_phase() -> StringName:
    return &"fps"
