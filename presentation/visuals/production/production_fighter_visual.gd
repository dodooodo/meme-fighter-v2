# Production sprite adapter. Presentation only; never mutates Fighter gameplay state.
# Parent local origin remains FEET CENTER. Runtime attack frames are selected from
# read-only MoveRunner phase facts; animation completion never controls gameplay.
class_name ProductionFighterVisual
extends FighterVisual

const ATTACK_KEYS: Array[StringName] = [
    &"stand_light", &"stand_heavy", &"crouch_low", &"air_attack",
    &"ground_throw", &"special_neutral", &"ultimate"
]

@export var sprite_frames: SpriteFrames
@export_file("*.json") var manifest_path: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _animation_frames: Dictionary = {}
var _animation_meta: Dictionary = {}
var _warned_missing: Dictionary = {}
var _greybox_fallback: bool = false
var _preview_mode: bool = false
var _preview_speed_scale: float = 1.0
var _presentation_phase: StringName = &"fps"
var _visual_hold_ticks: int = 0
var _flash_ticks: int = 0
var _flash_strength: float = 0.0
var _timeline_cache: Dictionary = {}

func _ready() -> void:
    _load_manifest()
    if sprite_frames != null:
        sprite.sprite_frames = sprite_frames
    sprite.centered = false
    if not sprite.frame_changed.is_connected(_on_frame_changed):
        sprite.frame_changed.connect(_on_frame_changed)
    play_animation(current_animation_key)

func _process(_delta: float) -> void:
    if _visual_hold_ticks > 0:
        _visual_hold_ticks -= 1
    if _flash_ticks > 0:
        _flash_ticks -= 1
        var amount := clampf(_flash_strength, 0.0, 1.0)
        sprite.self_modulate = Color(1.0, 1.0 - amount * 0.35, 1.0 - amount * 0.35, 1.0)
    else:
        sprite.self_modulate = Color.WHITE

func play_animation(animation_key: StringName) -> void:
    var requested := animation_key if animation_key != &"" else &"idle"
    var resolved := _resolve_animation_key(requested)
    super.play_animation(resolved if resolved != &"" else requested)
    _greybox_fallback = resolved == &""
    sprite.visible = not _greybox_fallback
    if _greybox_fallback:
        queue_redraw()
        return

    _presentation_phase = &"preview" if _preview_mode else &"fps"
    if _preview_mode or not ATTACK_KEYS.has(resolved):
        sprite.speed_scale = _preview_speed_scale if _preview_mode else 1.0
        if sprite.animation != resolved or not sprite.is_playing():
            sprite.play(resolved)
    else:
        # Attack playback is controlled by the read-only Move phase timeline.
        sprite.stop()
        sprite.animation = resolved
        sprite.frame = 0
        sprite.frame_progress = 0.0
        _presentation_phase = &"startup"
    _update_frame_pivot()
    queue_redraw()

func sync_move_timeline(move_id: StringName, move_frame: int, startup_frames: int, active_frames: int, recovery_frames: int) -> void:
    if _preview_mode or sprite == null or _greybox_fallback:
        return
    if not ATTACK_KEYS.has(current_animation_key):
        return
    if move_id == &"" or move_frame <= 0:
        return
    if _visual_hold_ticks > 0:
        return
    var frame_count := sprite.sprite_frames.get_frame_count(current_animation_key)
    if frame_count <= 0:
        return
    var cache_key := "%s:%d:%d:%d:%d" % [String(current_animation_key), frame_count, startup_frames, active_frames, recovery_frames]
    var timeline: Dictionary = _timeline_cache.get(cache_key, {})
    if timeline.is_empty():
        timeline = _build_move_timeline(current_animation_key, frame_count, startup_frames, active_frames, recovery_frames)
        _timeline_cache[cache_key] = timeline
    var frame_map: Array = timeline.get("frames", [])
    var phase_map: Array = timeline.get("phases", [])
    if frame_map.is_empty():
        return
    var tick_index := clampi(move_frame - 1, 0, frame_map.size() - 1)
    sprite.stop()
    sprite.animation = current_animation_key
    sprite.frame = clampi(int(frame_map[tick_index]), 0, frame_count - 1)
    sprite.frame_progress = 0.0
    _presentation_phase = StringName(String(phase_map[tick_index])) if tick_index < phase_map.size() else &"move"
    _update_frame_pivot()

func request_visual_hold(render_ticks: int) -> void:
    _visual_hold_ticks = maxi(_visual_hold_ticks, maxi(0, render_ticks))

func request_hit_flash(strength: float, render_ticks: int) -> void:
    _flash_strength = maxf(_flash_strength, clampf(strength, 0.0, 1.0))
    _flash_ticks = maxi(_flash_ticks, maxi(0, render_ticks))

func set_preview_mode(enabled: bool, speed_scale: float = 1.0) -> void:
    _preview_mode = enabled
    _preview_speed_scale = clampf(speed_scale, 0.05, 4.0)
    if sprite != null:
        sprite.speed_scale = _preview_speed_scale if _preview_mode else 1.0
        if _preview_mode and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(current_animation_key):
            sprite.play(current_animation_key)
            _presentation_phase = &"preview"

func debug_frame_number() -> int:
    return sprite.frame + 1 if sprite != null else 1

func debug_presentation_phase() -> StringName:
    return _presentation_phase

func _build_move_timeline(animation_key: StringName, frame_count: int, startup_ticks: int, active_ticks: int, recovery_ticks: int) -> Dictionary:
    var startup_unique := 1
    var active_unique := 1
    var recovery_unique := maxi(1, frame_count - 2)
    var startup_hold_frame := 0

    if animation_key == &"stand_light" and frame_count == 10:
        startup_unique = 3
        active_unique = 3
        recovery_unique = 4
        startup_hold_frame = 2
    elif animation_key == &"stand_heavy" and frame_count == 15:
        startup_unique = 6
        active_unique = 4
        recovery_unique = 5
        startup_hold_frame = 5
    elif animation_key == &"special_neutral" and frame_count == 25:
        # Reserve presentation ticks inside authoritative startup for anticipation.
        var special_hold := 2
        startup_unique = clampi(startup_ticks - special_hold, 4, 12)
        active_unique = clampi(active_ticks, 1, mini(5, frame_count - startup_unique - 1))
        recovery_unique = frame_count - startup_unique - active_unique
        startup_hold_frame = mini(3, startup_unique - 1)
    elif animation_key == &"ultimate" and frame_count == 25:
        # Strong 4-tick anticipation hold, still entirely inside MoveData startup.
        var ultimate_hold := 4
        startup_unique = clampi(startup_ticks - ultimate_hold, 8, 14)
        active_unique = clampi(active_ticks, 1, mini(5, frame_count - startup_unique - 1))
        recovery_unique = frame_count - startup_unique - active_unique
        startup_hold_frame = mini(7, startup_unique - 1)
    else:
        var total_ticks := maxi(1, startup_ticks + active_ticks + recovery_ticks)
        startup_unique = clampi(int(round(float(frame_count) * float(startup_ticks) / float(total_ticks))), 1, maxi(1, frame_count - 2))
        active_unique = clampi(int(round(float(frame_count) * float(active_ticks) / float(total_ticks))), 1, maxi(1, frame_count - startup_unique - 1))
        recovery_unique = maxi(1, frame_count - startup_unique - active_unique)
        startup_hold_frame = startup_unique - 1

    # Correct any rounding edge case while preserving every authored visual frame.
    recovery_unique += frame_count - (startup_unique + active_unique + recovery_unique)
    if recovery_unique <= 0:
        recovery_unique = 1
        if startup_unique > active_unique and startup_unique > 1:
            startup_unique -= 1
        elif active_unique > 1:
            active_unique -= 1

    var frames: Array[int] = []
    var phases: Array[StringName] = []
    _append_expanded_phase(frames, phases, 0, startup_unique, maxi(1, startup_ticks), startup_hold_frame, &"startup")
    _append_expanded_phase(frames, phases, startup_unique, active_unique, maxi(1, active_ticks), startup_unique + maxi(0, int(active_unique / 2)), &"active")
    _append_expanded_phase(frames, phases, startup_unique + active_unique, recovery_unique, maxi(1, recovery_ticks), frame_count - 1, &"recovery")
    return {"frames": frames, "phases": phases}

func _append_expanded_phase(target_frames: Array[int], target_phases: Array[StringName], first_frame: int, unique_count: int, tick_count: int, hold_frame: int, phase_name: StringName) -> void:
    unique_count = maxi(1, unique_count)
    tick_count = maxi(1, tick_count)
    var local: Array[int] = []
    if tick_count >= unique_count:
        # Preserve all authored frames; put extra ticks on the anticipation/contact/final hold.
        var extra := tick_count - unique_count
        for i in range(unique_count):
            local.append(first_frame + i)
            if first_frame + i == hold_frame:
                for _j in range(extra):
                    local.append(first_frame + i)
                extra = 0
        while extra > 0:
            local.append(first_frame + unique_count - 1)
            extra -= 1
    else:
        # Fallback for an unexpectedly short phase: evenly sample without affecting gameplay.
        for tick in range(tick_count):
            var sample := int(floor(float(tick) * float(unique_count) / float(tick_count)))
            local.append(first_frame + mini(sample, unique_count - 1))
    for value in local:
        target_frames.append(value)
        target_phases.append(phase_name)

func _resolve_animation_key(requested: StringName) -> StringName:
    if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(requested):
        return requested
    _warn_missing_once(requested)
    var fallback := _generic_fallback(requested)
    if fallback != &"" and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(fallback):
        return fallback
    if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
        return &"idle"
    return &""

func _generic_fallback(requested: StringName) -> StringName:
    if requested in [&"hitstun", &"blockstun", &"thrown", &"knockdown", &"getup", &"ko"]:
        return &"hitstun"
    if requested in [&"attack", &"stand_light", &"stand_heavy", &"crouch_low", &"air_attack", &"ground_throw", &"special_neutral", &"ultimate"]:
        return &"stand_light"
    return &""

func _warn_missing_once(animation_key: StringName) -> void:
    if _warned_missing.has(animation_key):
        return
    _warned_missing[animation_key] = true
    push_warning("ProductionFighterVisual missing animation '%s'; applying presentation fallback" % String(animation_key))

func _load_manifest() -> void:
    _animation_frames.clear()
    _animation_meta.clear()
    if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
        push_warning("ProductionFighterVisual manifest missing: %s" % manifest_path)
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    if not (parsed is Dictionary):
        push_warning("ProductionFighterVisual manifest is invalid JSON: %s" % manifest_path)
        return
    var animations: Variant = parsed.get("animations", [])
    if not (animations is Array):
        return
    for item: Variant in animations:
        if not (item is Dictionary):
            continue
        var key := StringName(String(item.get("key", "")))
        if key == &"":
            continue
        _animation_frames[key] = item.get("frames", [])
        _animation_meta[key] = item

func _on_frame_changed() -> void:
    _update_frame_pivot()

func _update_frame_pivot() -> void:
    if sprite == null:
        return
    var frames: Variant = _animation_frames.get(sprite.animation, [])
    if not (frames is Array) or frames.is_empty():
        sprite.position = Vector2.ZERO
        return
    var index := clampi(sprite.frame, 0, frames.size() - 1)
    var frame_meta: Variant = frames[index]
    if not (frame_meta is Dictionary):
        return
    var pivot: Variant = frame_meta.get("pivot_pixels", [])
    if pivot is Array and pivot.size() == 2:
        # Sprite is top-left anchored. Shared animation-level feet baseline maps to local (0,0).
        sprite.position = Vector2(-float(pivot[0]), -float(pivot[1]))

func _draw() -> void:
    if not _greybox_fallback:
        return
    draw_rect(Rect2(Vector2(-28, -150), Vector2(56, 150)), Color(0.55, 0.55, 0.6, 1.0), true)
