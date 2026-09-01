# Presentation-only renderer for inventory-backed ACTION_FOLDERS production frames.
# Local origin is FEET_CENTER using canvas bottom-center; alpha bounds never drive anchoring.
# Move playback samples key poses from authoritative MoveData timing; image count never controls gameplay.
class_name InventoryBoundFighterVisual
extends FighterVisual

@onready var sprite: Sprite2D = $Sprite2D
var active_mode_id: StringName = &""
var _binding: ProductionAnimationBinding = null
var _frame_index: int = 0
var _elapsed: float = 0.0
var _visual_hold_ticks: int = 0
var _flash_ticks: int = 0
var _flash_strength: float = 0.0
var _preview_mode: bool = false
var _preview_speed_scale: float = 1.0
var _presentation_phase: StringName = &"state"

func play_animation(animation_key: StringName) -> void:
    super.play_animation(animation_key)
    _binding = _resolve_binding(current_animation_key)
    if _binding == null:
        _binding = _resolve_binding(&"idle")
    _frame_index = 0
    _elapsed = 0.0
    _presentation_phase = &"state"
    _apply_frame()

func apply_presentation_mode_id(mode_id: StringName) -> void:
    if active_mode_id == mode_id:
        return
    active_mode_id = mode_id
    play_animation(current_animation_key)

func _process(delta: float) -> void:
    if _visual_hold_ticks > 0:
        _visual_hold_ticks -= 1
    if _flash_ticks > 0:
        _flash_ticks -= 1
        var amount := clampf(_flash_strength, 0.0, 1.0)
        sprite.self_modulate = Color(1.0, 1.0 - amount * 0.35, 1.0 - amount * 0.35, 1.0)
    else:
        sprite.self_modulate = Color.WHITE
    if _binding == null or _binding.frame_paths.size() <= 1 or _visual_hold_ticks > 0:
        return
    if _binding.hold_policy == ProductionAnimationBinding.HoldPolicy.MOVE_TIMELINE and not _preview_mode:
        return
    var fps := 8.0 * _preview_speed_scale
    _elapsed += delta
    var wanted := int(floor(_elapsed * fps))
    if _binding.loop or _binding.hold_policy == ProductionAnimationBinding.HoldPolicy.LOOP:
        wanted %= _binding.frame_paths.size()
    else:
        wanted = mini(wanted, _binding.frame_paths.size() - 1)
    if wanted != _frame_index:
        _frame_index = wanted
        _apply_frame()

func sync_move_timeline(_move_id: StringName, move_frame: int, startup_frames: int, active_frames: int, recovery_frames: int) -> void:
    if _binding == null or _binding.frame_paths.is_empty() or _preview_mode or _visual_hold_ticks > 0:
        return
    if not _binding.is_fighter_domain():
        return
    var total := maxi(1, startup_frames + active_frames + recovery_frames)
    var normalized := clampf(float(maxi(1, move_frame) - 1) / float(total), 0.0, 0.999999)
    var wanted := mini(_binding.frame_paths.size() - 1, int(floor(normalized * float(_binding.frame_paths.size()))))
    if move_frame <= startup_frames:
        _presentation_phase = &"startup"
    elif move_frame <= startup_frames + active_frames:
        _presentation_phase = &"active"
    else:
        _presentation_phase = &"recovery"
    if wanted != _frame_index:
        _frame_index = wanted
        _apply_frame()

func request_visual_hold(render_ticks: int) -> void:
    _visual_hold_ticks = maxi(_visual_hold_ticks, maxi(0, render_ticks))

func request_hit_flash(strength: float, render_ticks: int) -> void:
    _flash_strength = maxf(_flash_strength, clampf(strength, 0.0, 1.0))
    _flash_ticks = maxi(_flash_ticks, maxi(0, render_ticks))

func set_preview_mode(enabled: bool, speed_scale: float = 1.0) -> void:
    _preview_mode = enabled
    _preview_speed_scale = clampf(speed_scale, 0.05, 4.0)

func debug_frame_number() -> int:
    return _frame_index + 1

func debug_presentation_phase() -> StringName:
    return _presentation_phase

func _resolve_binding(animation_key: StringName) -> ProductionAnimationBinding:
    if presentation_data == null or presentation_data.production_asset_binding == null:
        return null
    var binding := presentation_data.production_asset_binding.binding_for_animation(animation_key, active_mode_id)
    if binding != null and binding.is_fighter_domain():
        return binding
    if animation_key != &"special_neutral":
        binding = presentation_data.production_asset_binding.binding_for_animation(&"special_neutral", active_mode_id)
        if binding != null and binding.is_fighter_domain():
            return binding
    return null

func _apply_frame() -> void:
    if sprite == null:
        return
    if _binding == null or _binding.frame_paths.is_empty():
        sprite.texture = null
        return
    _frame_index = clampi(_frame_index, 0, _binding.frame_paths.size() - 1)
    var path := _binding.frame_paths[_frame_index]
    var texture := load(path) as Texture2D
    sprite.texture = texture
    sprite.centered = false
    if texture != null:
        # FEET_CENTER from authored canvas geometry, never alpha bounds.
        sprite.position = Vector2(-float(texture.get_width()) * 0.5, -float(texture.get_height()))
