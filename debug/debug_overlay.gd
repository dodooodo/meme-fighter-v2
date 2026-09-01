# Responsibility: Read-only developer diagnostics for simulation and frame-step state.
# Owns: debug text visibility.
# Does NOT own: simulation mutation, frame stepping decisions, combat decisions.
# Dependencies: BattleSimulation read-only state, FrameStepper read-only status.
class_name DebugOverlay
extends Control

@onready var label: Label = $Panel/Label
var enabled: bool = true
var frame_stepper: FrameStepper = null
var presentation_controller: BattlePresentationController = null

func set_frame_stepper(value: FrameStepper) -> void:
    frame_stepper = value

func set_presentation_controller(value: BattlePresentationController) -> void:
    presentation_controller = value

func toggle() -> void:
    enabled = not enabled
    visible = enabled

func update_from_simulation(simulation: BattleSimulation) -> void:
    if not enabled or simulation == null:
        return
    var run_state := "Paused" if frame_stepper != null and frame_stepper.paused else "Running"
    var round := simulation.round_controller
    var timer_text := "∞" if round.rules != null and not round.rules.timer_enabled else str(round.timer_display_seconds())
    var lines: PackedStringArray = []
    lines.append("Tick %d | %s | FPS %d | Rules: %s | Round State: %s | Round: %d | Round Wins: P1 %d/P2 %d | Timer Frames: %d | Timer: %s | Post Round: %d | Match Winner: %s" % [simulation.frame_number, run_state, Engine.get_frames_per_second(), String(round.rules.id) if round.rules != null else "<none>", round.state_name(), round.round_number, round.p1_round_wins, round.p2_round_wins, round.round_timer_remaining_frames, timer_text, round.post_round_remaining_frames, round.winner_name(round.match_winner)])
    lines.append(_fighter_line(simulation.fighter_a, simulation.frame_number))
    lines.append(_fighter_line(simulation.fighter_b, simulation.frame_number))
    lines.append("Projectiles=%d Areas/Summons/Hazards/Sequences=%d | PendingThrows=%d" % [simulation.projectile_system.active_projectiles().size(), simulation.temporary_entity_system.active_entities().size(), simulation.pending_normal_throw_count()])
    lines.append(_entity_line(simulation))
    lines.append("Inputs P1: %s" % simulation.fighter_a.input_history.debug_string(10))
    lines.append("Inputs P2: %s" % simulation.fighter_b.input_history.debug_string(10))
    lines.append(presentation_controller.diagnostic_summary() if presentation_controller != null else "Presentation: NONE")
    label.text = "\n".join(lines)

func _fighter_line(fighter: Fighter, current_frame: int) -> String:
    var read := fighter.capture_combat_read()
    var move := fighter.move_runner.current_move
    var move_id := String(read["current_move_id"]) if move != null else "-"
    var advantage := "H%+d/B%+d" % [FrameAdvantageCalculator.on_hit(move), FrameAdvantageCalculator.on_block(move)] if move != null else "H-/B-"
    var status_parts: PackedStringArray = []
    var status_ids: Dictionary = {}
    for status: Dictionary in read["statuses"]:
        var id := StringName(str(status.get("id", "")))
        status_ids[id] = true
        status_parts.append("%s:%d%s" % [String(id), int(status.get("remaining", 0)), "+EXT" if bool(status.get("extended_once", false)) else ""])
    var resources := read["resources"] as Dictionary
    return "P%d %s | State=%s Move=%s F%d %s Adv=%s | HP=%d/%d Meter=%d | HS=%d BS=%d Stop=%d | Combo=%d Dmg=%d Scale=%d%% DC=%d | Charge=%dF/Lv%d | ThrowProtect=%d ThrowInv=%s Tech=%s | Mode=%s:%d | Res=%s | Status=%s | Signal=%s Panic=%s Sticky=%s Courage=%d Stars=%d Resolve=%d" % [
        int(read["fighter_id"]), String(read["character_id"]), String(read["state_name"]), move_id, int(read["current_move_frame"]), String(read["current_move_phase"]), advantage,
        int(read["hp"]), int(read["max_hp"]), int(read["meter"]), int(read["hitstun_remaining"]), int(read["blockstun_remaining"]), int(read["hitstop_remaining"]),
        int(read["combo_hit_count"]), int(read["combo_damage"]), int(read["combo_scale_percent"]), int(read["dash_cancel_count"]),
        int(read["charge_frames"]), int(read["charge_level"]), int(read["throw_protection_frames"]), str(read["backstep_throw_invulnerable"]), str(read["throw_tech_pending"]),
        String(read["active_mode_id"]), int(read["mode_remaining_frames"]), str(resources), ",".join(status_parts),
        str(status_ids.has(&"signal_mark")), str(status_ids.has(&"panic_exit")), str(status_ids.has(&"sauce")),
        int(resources.get("courage", 0)), int(resources.get("face_actions", 0)), int(resources.get("resolve", 0))]

func _entity_line(simulation: BattleSimulation) -> String:
    var values: PackedStringArray = []
    for runtime: TemporaryEntityRuntime in simulation.temporary_entity_system.active_entities():
        values.append("#%d %s kind=%d hp=%d life=%d phase=%d/%d" % [runtime.instance_id, String(runtime.data_id), runtime.kind, runtime.hp, runtime.remaining_lifetime_frames, runtime.phase, runtime.phase_remaining])
    return "Entities: " + (" | ".join(values) if not values.is_empty() else "-")
