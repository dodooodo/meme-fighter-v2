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
    var projectile_lines: PackedStringArray = []
    var active := simulation.projectile_system.active_projectiles()
    for i in range(mini(active.size(), 4)):
        var projectile: ProjectileRuntime = active[i]
        projectile_lines.append("  #%d %s Owner P%d Pos %d/%d Facing %d Life %d" % [
            projectile.instance_id,
            String(projectile.projectile_id),
            projectile.owner_fighter_id,
            projectile.position_units.x,
            projectile.position_units.y,
            projectile.facing,
            projectile.remaining_lifetime_frames,
        ])
    if active.size() > 4:
        projectile_lines.append("  ... +%d more" % (active.size() - 4))
    var projectile_summary := "Active Projectiles: %d" % active.size()
    if not projectile_lines.is_empty():
        projectile_summary += "\n" + "\n".join(projectile_lines)
    var round := simulation.round_controller
    var timer_text := "∞" if round.rules != null and not round.rules.timer_enabled else str(round.timer_display_seconds())
    var match_summary := "Rules: %s | Round State: %s | Round: %d | Round Wins: P1 %d / P2 %d | Timer Frames: %d | Timer Display: %s | Post Round: %d | Match Winner: %s" % [
        String(round.rules.id) if round.rules != null else "<none>",
        round.state_name(),
        round.round_number,
        round.p1_round_wins,
        round.p2_round_wins,
        round.round_timer_remaining_frames,
        timer_text,
        round.post_round_remaining_frames,
        round.winner_name(round.match_winner),
    ]
    var replay_summary := "Replay: %s" % ("RECORDING" if simulation.replay_recorder != null and simulation.replay_recorder.is_recording() else "OFF")
    var presentation_summary := presentation_controller.diagnostic_summary() if presentation_controller != null else "Presentation: NONE"
    label.text = "Simulation Frame %d | %s | Render FPS %d\n%s\n%s\n%s\n%s\n%s\n%s\nInputs P1: %s\nInputs P2: %s" % [
        simulation.frame_number,
        run_state,
        Engine.get_frames_per_second(),
        match_summary,
        replay_summary,
        presentation_summary,
        simulation.fighter_a.debug_summary(simulation.frame_number),
        simulation.fighter_b.debug_summary(simulation.frame_number),
        projectile_summary,
        simulation.fighter_a.input_history.debug_string(10),
        simulation.fighter_b.input_history.debug_string(10),
    ]
