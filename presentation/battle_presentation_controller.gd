# Scene-level one-way presentation orchestrator. BattleSimulation never depends on this node.
class_name BattlePresentationController
extends Node

@onready var fighter_root: Node2D = $World/Fighters
@onready var projectile_presenter: ProjectileVisualPresenter = $World/Projectiles
@onready var vfx_presenter: CombatVfxPresenter = $World/VFX
@onready var world_effect_presenter: WorldEffectPresenter = $World/WorldEffects
@onready var temporary_entity_presenter: TemporaryEntityVisualPresenter = $World/TemporaryEntities
@onready var ultimate_screen_presenter: UltimateScreenPresenter = $UltimateScreens
@onready var audio_presenter: CombatAudioPresenter = $Audio
@onready var camera_controller: BattleCameraController = $World/CameraFeedback

var simulation: BattleSimulation
var p1_data: CharacterPresentationData
var p2_data: CharacterPresentationData
var p1_controller: FighterPresentationController
var p2_controller: FighterPresentationController
var hud: BattleHUD
var round_overlay: RoundPresentationOverlay
var ledger: PresentationEventLedger = PresentationEventLedger.new()
var configured: bool = false

func configure(
    p_simulation: BattleSimulation,
    p1_presentation: CharacterPresentationData,
    p2_presentation: CharacterPresentationData,
    p_hud: BattleHUD = null,
    p_round_overlay: RoundPresentationOverlay = null
) -> bool:
    clear_runtime_visuals()
    simulation = p_simulation
    p1_data = p1_presentation
    p2_data = p2_presentation
    hud = p_hud
    round_overlay = p_round_overlay
    configured = false
    if simulation == null or p1_data == null or p2_data == null:
        push_error("BattlePresentationController missing simulation/presentation data")
        return false
    if not p1_data.validate(simulation.fighter_a.data.id).is_empty() or not p2_data.validate(simulation.fighter_b.data.id).is_empty():
        push_error("BattlePresentationController character/presentation ID mismatch")
        return false
    if hud != null:
        hud.configure(p1_data, p2_data)
    p1_controller = FighterPresentationController.new()
    p2_controller = FighterPresentationController.new()
    add_child(p1_controller)
    add_child(p2_controller)
    if not p1_controller.configure(simulation.fighter_a, p1_data, fighter_root):
        return false
    if not p2_controller.configure(simulation.fighter_b, p2_data, fighter_root):
        return false
    var presentations: Array[CharacterPresentationData] = [p1_data, p2_data]
    projectile_presenter.configure(simulation, presentations)
    temporary_entity_presenter.configure(simulation, presentations)
    world_effect_presenter.configure(presentations, {
        simulation.fighter_a.fighter_id: p1_controller,
        simulation.fighter_b.fighter_id: p2_controller,
    })
    ultimate_screen_presenter.configure(simulation, presentations)
    camera_controller.configure(simulation)
    ledger.clear()
    configured = true
    resync_all()
    return true

func _process(_delta: float) -> void:
    if configured:
        sync_from_simulation()

func sync_from_simulation() -> void:
    if not configured or simulation == null:
        return
    p1_controller.apply_authoritative_mode_id(simulation.fighter_a.mode.active_mode_id)
    p2_controller.apply_authoritative_mode_id(simulation.fighter_b.mode.active_mode_id)
    p1_controller.sync_from_simulation()
    p2_controller.sync_from_simulation()
    projectile_presenter.sync_from_simulation()
    temporary_entity_presenter.sync_from_simulation()
    camera_controller.sync_follow()
    if hud != null:
        hud.update_from_simulation(simulation)
    if round_overlay != null:
        round_overlay.sync_from_simulation(simulation)

func consume_events(events: Array[CombatEvent]) -> void:
    for event: CombatEvent in events:
        if event == null or not ledger.consume_once(event):
            continue
        vfx_presenter.present_event(event)
        world_effect_presenter.present_event(event, simulation)
        ultimate_screen_presenter.present_event(event)
        audio_presenter.present_event(event)
        camera_controller.present_event(event)
        _present_character_impact(event)
        if round_overlay != null:
            round_overlay.present_event(event)
        if event.type == CombatEvent.EventType.ROUND_STARTED:
            vfx_presenter.clear_all()
            world_effect_presenter.clear_all()


func _present_character_impact(event: CombatEvent) -> void:
    if event == null or event.type not in [CombatEvent.EventType.HIT, CombatEvent.EventType.BLOCK]:
        return
    var attacker_controller := _controller_for_fighter_id(event.attacker_id)
    var defender_controller := _controller_for_fighter_id(event.defender_id)
    var tier := CombatFeedbackProfile.tier_for_move(event.move_id)
    if event.type == CombatEvent.EventType.BLOCK:
        if attacker_controller != null:
            attacker_controller.request_visual_hold(1 if tier >= 3 else 0)
        if defender_controller != null:
            defender_controller.request_hit_flash(0.22 + 0.06 * float(tier), 1)
        return

    var hold_ticks := 0
    var flash_ticks := 1
    var flash_strength := 0.28
    match tier:
        2:
            hold_ticks = 1
            flash_ticks = 2
            flash_strength = 0.42
        3:
            hold_ticks = 2
            flash_ticks = 2
            flash_strength = 0.58
        4:
            hold_ticks = 3
            flash_ticks = 3
            flash_strength = 0.78
    if attacker_controller != null:
        attacker_controller.request_visual_hold(hold_ticks)
        attacker_controller.request_hit_flash(flash_strength * 0.72, flash_ticks)
    if defender_controller != null:
        defender_controller.request_visual_hold(hold_ticks)
        defender_controller.request_hit_flash(flash_strength, flash_ticks)

func _controller_for_fighter_id(fighter_id: int) -> FighterPresentationController:
    if simulation == null:
        return null
    if simulation.fighter_a != null and simulation.fighter_a.fighter_id == fighter_id:
        return p1_controller
    if simulation.fighter_b != null and simulation.fighter_b.fighter_id == fighter_id:
        return p2_controller
    return null

func resync_all() -> void:
    if not configured:
        return
    projectile_presenter.sync_from_simulation()
    p1_controller.apply_authoritative_mode_id(simulation.fighter_a.mode.active_mode_id)
    p2_controller.apply_authoritative_mode_id(simulation.fighter_b.mode.active_mode_id)
    p1_controller.sync_from_simulation()
    p2_controller.sync_from_simulation()
    if hud != null:
        hud.update_from_simulation(simulation)
    if round_overlay != null:
        round_overlay.sync_from_simulation(simulation)
    camera_controller.sync_follow()

func on_snapshot_restored(restored_frame: int) -> void:
    # Stateful visuals rebuild from simulation. One-shot VFX/audio are not restored.
    vfx_presenter.clear_all()
    world_effect_presenter.clear_all()
    ultimate_screen_presenter.clear_all()
    ledger.forget_after_frame(restored_frame)
    resync_all()

func on_round_reset() -> void:
    vfx_presenter.clear_all()
    world_effect_presenter.clear_all()
    ultimate_screen_presenter.clear_all()
    projectile_presenter.sync_from_simulation()
    resync_all()

func on_full_match_reset() -> void:
    vfx_presenter.clear_all()
    world_effect_presenter.clear_all()
    ultimate_screen_presenter.clear_all()
    projectile_presenter.clear_all()
    ledger.clear()
    camera_controller.reset_feedback()
    if round_overlay != null:
        round_overlay.reset_overlay()
    resync_all()

func clear_runtime_visuals() -> void:
    configured = false
    if p1_controller != null:
        p1_controller.clear_visual()
        p1_controller.queue_free()
    if p2_controller != null:
        p2_controller.clear_visual()
        p2_controller.queue_free()
    p1_controller = null
    p2_controller = null
    if is_instance_valid(projectile_presenter):
        projectile_presenter.clear_all()
    if is_instance_valid(temporary_entity_presenter):
        temporary_entity_presenter.clear_all()
    if is_instance_valid(vfx_presenter):
        vfx_presenter.clear_all()
    if is_instance_valid(world_effect_presenter):
        world_effect_presenter.clear_all()
    if is_instance_valid(ultimate_screen_presenter):
        ultimate_screen_presenter.clear_all()

func diagnostic_summary() -> String:
    if not configured:
        return "Presentation: UNCONFIGURED"
    return "Visual P1=%s P2=%s | Ledger=%d Last=%s | Camera=%s" % [
        String(p1_controller.current_animation_key),
        String(p2_controller.current_animation_key),
        ledger.count(),
        ledger.last_presented_event_id,
        camera_controller.feedback_state(),
    ]
