# One-way Fighter simulation -> visual adapter binding.
# Mode swaps replace only the Presentation child; Fighter gameplay identity/state is untouched.
class_name FighterPresentationController
extends Node

var fighter: Fighter
var data: CharacterPresentationData
var visual: FighterVisual
var current_animation_key: StringName = &"idle"
var active_mode_id: StringName = &""
var active_mode_binding: ModePresentationBinding
var configuration_error: String = ""
var _visual_parent: Node
var _warned_missing_modes: Dictionary = {}

func configure(p_fighter: Fighter, p_data: CharacterPresentationData, visual_parent: Node) -> bool:
    fighter = p_fighter
    data = p_data
    _visual_parent = visual_parent
    configuration_error = ""
    active_mode_id = &""
    active_mode_binding = null
    if fighter == null or fighter.data == null or data == null:
        configuration_error = "missing Fighter or CharacterPresentationData"
        return false
    var errors := data.validate(fighter.data.id)
    if not errors.is_empty():
        configuration_error = "; ".join(errors)
        push_error(configuration_error)
        return false
    data.rebuild_cache()
    if not _instantiate_visual(data.fighter_visual_scene, 1.0):
        return false
    sync_from_simulation()
    return true

# Presentation entry point for a future authoritative gameplay mode id.
# M9P deliberately does not invent or mutate gameplay mode state.
func apply_authoritative_mode_id(mode_id: StringName) -> bool:
    if data == null or mode_id == active_mode_id:
        return true
    if mode_id == &"":
        active_mode_id = &""
        active_mode_binding = null
        if visual != null:
            visual.apply_presentation_mode_id(&"")
            visual.play_animation(current_animation_key)
            return true
        return _swap_visual(data.fighter_visual_scene, 1.0, &"idle")
    var binding := data.mode_binding(mode_id)
    if data.production_asset_binding != null and data.production_asset_binding.has_mode(mode_id):
        active_mode_id = mode_id
        active_mode_binding = binding
        if visual != null:
            visual.apply_presentation_mode_id(mode_id)
            visual.play_animation(current_animation_key)
            return true
    if binding == null or binding.fighter_visual_scene == null:
        if not _warned_missing_modes.has(mode_id):
            _warned_missing_modes[mode_id] = true
            push_warning("Missing MODE_FIGHTER presentation for '%s'; using BASE_FIGHTER visual" % String(mode_id))
        active_mode_id = mode_id
        active_mode_binding = null
        return _swap_visual(data.fighter_visual_scene, 1.0, current_animation_key)
    active_mode_id = mode_id
    active_mode_binding = binding
    return _swap_visual(binding.fighter_visual_scene, binding.visual_scale, binding.enter_animation)

func sync_from_simulation() -> void:
    if fighter == null or visual == null or data == null:
        return
    var offset := data.visual_offset_pixels
    if active_mode_binding != null:
        offset += active_mode_binding.visual_offset_pixels
    visual.set_screen_position(SimulationRenderConverter.to_pixels(fighter.movement_motor.sim_position) + offset)
    visual.set_facing(fighter.movement_motor.facing)
    var resolved := FighterPresentationResolver.resolve_animation(fighter, data)
    if resolved != current_animation_key:
        current_animation_key = resolved
        visual.play_animation(resolved)
    _sync_read_only_move_timeline()

func _instantiate_visual(scene: PackedScene, scale_multiplier: float) -> bool:
    var node: Node = scene.instantiate() if scene != null else GreyboxFighterVisual.new()
    visual = node as FighterVisual
    if visual == null:
        if node != null:
            node.queue_free()
        visual = GreyboxFighterVisual.new()
    if _visual_parent == null:
        configuration_error = "missing visual parent"
        return false
    _visual_parent.add_child(visual)
    visual.set_character_presentation_data(data)
    visual.set_visual_scale_multiplier(scale_multiplier)
    return true

func _swap_visual(scene: PackedScene, scale_multiplier: float, start_animation: StringName) -> bool:
    var old_visual := visual
    visual = null
    if not _instantiate_visual(scene, scale_multiplier):
        visual = old_visual
        return false
    if old_visual != null and is_instance_valid(old_visual):
        old_visual.queue_free()
    if fighter != null:
        visual.set_facing(fighter.movement_motor.facing)
    visual.apply_presentation_mode_id(active_mode_id)
    visual.play_animation(start_animation if start_animation != &"" else current_animation_key)
    sync_from_simulation()
    return true

func _sync_read_only_move_timeline() -> void:
    if fighter == null or fighter.move_runner == null or visual == null:
        return
    var move: MoveData = fighter.move_runner.current_move
    if move == null:
        return
    visual.sync_move_timeline(
        fighter.move_runner.current_move_id(),
        fighter.move_runner.move_frame,
        move.startup_frames,
        move.active_frames,
        move.recovery_frames
    )

func request_visual_hold(render_ticks: int) -> void:
    if visual != null:
        visual.request_visual_hold(render_ticks)

func request_hit_flash(strength: float, render_ticks: int) -> void:
    if visual != null:
        visual.request_hit_flash(strength, render_ticks)

func clear_visual() -> void:
    if visual != null and is_instance_valid(visual):
        visual.queue_free()
    visual = null
    active_mode_id = &""
    active_mode_binding = null
