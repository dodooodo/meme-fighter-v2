# Responsibility: Scene-level wiring between fixed gameplay simulation and one-way observers/presentation.
# Owns: render scheduler, match-mode InputSource wiring, presentation configuration, replay/telemetry lifecycle and event draining.
# Does NOT own: combat rules, collision, HP/meter mutation, round authority, animation-driven gameplay.
class_name BattleScene
extends Node

var simulation: BattleSimulation
var clock: SimulationClock = SimulationClock.new()
var frame_stepper: FrameStepper = FrameStepper.new()
var battle_mode: int = BattleMode.Mode.LOCAL_2P
var telemetry_service: TelemetryService
var replay_recorder: ReplayRecorder
var replay_id: String = ""
var replay_directory: String = TelemetryReplayStore.DEFAULT_DIRECTORY
var _match_finalized: bool = true
@export var character_a_data: CharacterData
@export var character_b_data: CharacterData
@export var character_a_presentation: CharacterPresentationData
@export var character_b_presentation: CharacterPresentationData
@export var match_rules_data: MatchRulesData

@onready var battle_view: BattleView = $BattleView
@onready var presentation_controller: BattlePresentationController = $BattlePresentationController
@onready var hitbox_debugger: HitboxDebugger = $HitboxDebugger
@onready var hud: BattleHUD = $CanvasLayer/BattleHUD
@onready var round_overlay: RoundPresentationOverlay = $CanvasLayer/RoundOverlay
@onready var debug_overlay: DebugOverlay = $CanvasLayer/DebugOverlay
@onready var mode_label: Label = $CanvasLayer/ModeIndicator

func _ready() -> void:
    telemetry_service = get_node_or_null("/root/Telemetry") as TelemetryService
    if telemetry_service == null:
        telemetry_service = TelemetryService.new()
        telemetry_service.name = "BattleTelemetryFallback"
        add_child(telemetry_service)
    telemetry_service.ensure_configured()
    debug_overlay.set_frame_stepper(frame_stepper)
    debug_overlay.set_presentation_controller(presentation_controller)
    _reset_battle()

func _process(delta: float) -> void:
    if simulation == null:
        return
    var ticks := frame_stepper.consume_ticks(clock, delta)
    for _i in range(ticks):
        simulation.sample_and_simulate_frame()
        _consume_simulation_events(simulation.drain_events())
    presentation_controller.sync_from_simulation()
    debug_overlay.update_from_simulation(simulation)
    telemetry_service.sample_performance(delta, Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.MEMORY_STATIC)))
    telemetry_service.flush()

func _exit_tree() -> void:
    _finalize_match("scene_exit")
    if telemetry_service != null:
        telemetry_service.flush_blocking(256)

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F1:
            hitbox_debugger.toggle()
        KEY_F2:
            debug_overlay.toggle()
        KEY_F3:
            frame_stepper.toggle_pause(clock)
        KEY_F4:
            frame_stepper.request_advance(1, clock)
        KEY_F5:
            frame_stepper.request_advance(5, clock)
        KEY_R:
            _reset_battle()
        KEY_ESCAPE:
            get_tree().change_scene_to_file("res://frontend/mode_select_scene.tscn")

func _reset_battle() -> void:
    _finalize_match("reset")
    var load_started_usec := Time.get_ticks_usec()
    var source_p1: InputSource = BattleInputWiring.create_p1_source()
    var source_p2: InputSource = BattleInputWiring.create_p2_source(battle_mode)
    var cpu_source := source_p2 as CpuInputSource

    simulation = BattleSimulation.new()
    simulation.configure(
        character_a_data,
        character_b_data,
        source_p1,
        source_p2,
        Vector2i(50000, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(78000, BattleSimulation.GROUND_Y_UNITS),
        match_rules_data
    )
    if cpu_source != null and not cpu_source.bind_context(simulation.fighter_b, simulation.fighter_a, simulation):
        push_error("CpuInputSource context binding failed")
        telemetry_service.record_error("CPU_CONTEXT_BIND_FAILED", "CPU input context binding failed")
    simulation.combat_logger.enabled = OS.is_debug_build()
    var match_id := telemetry_service.begin_match(
        String(simulation.fighter_a.data.id),
        String(simulation.fighter_b.data.id),
        "vs_cpu" if battle_mode == BattleMode.Mode.VS_CPU else "local_2p",
        "",
        simulation.frame_number
    )
    replay_id = telemetry_service.current_replay_id()
    replay_recorder = ReplayRecorder.new()
    if match_id.is_empty() or not replay_recorder.begin_recording(
        simulation.round_controller.rules.id,
        simulation.fighter_a.data.id,
        simulation.fighter_b.data.id,
        simulation.frame_number
    ):
        telemetry_service.record_error("REPLAY_RECORDING_START_FAILED", "Replay recording could not start")
        replay_recorder = null
    else:
        simulation.set_replay_recorder(replay_recorder)
    _match_finalized = false
    clock.reset()
    frame_stepper.reset()
    battle_view.set_simulation(simulation)
    hitbox_debugger.set_simulation(simulation)
    mode_label.text = "%s%s" % [BattleMode.display_name(battle_mode), " | P2 [CPU]" if battle_mode == BattleMode.Mode.VS_CPU else ""]
    var asset_load_started_usec := Time.get_ticks_usec()
    if not presentation_controller.configure(simulation, character_a_presentation, character_b_presentation, hud, round_overlay):
        push_error("Battle presentation configuration failed; simulation remains independently valid")
        telemetry_service.record_error("PRESENTATION_CONFIGURATION_FAILED", "Battle presentation configuration failed")
    telemetry_service.record_asset_pack_load_duration(float(Time.get_ticks_usec() - asset_load_started_usec) / 1000.0)
    _consume_simulation_events(simulation.drain_events())
    debug_overlay.update_from_simulation(simulation)
    telemetry_service.record_load_duration(float(Time.get_ticks_usec() - load_started_usec) / 1000.0)

func _consume_simulation_events(events: Array[CombatEvent]) -> void:
    telemetry_service.observe_combat_events(events, simulation)
    presentation_controller.consume_events(events)
    for event in events:
        if event != null and event.type == CombatEvent.EventType.MATCH_ENDED:
            _finalize_match("completed")

func _finalize_match(disconnect_reason: String) -> void:
    if _match_finalized or simulation == null or telemetry_service == null:
        return
    var correlation: Dictionary = {
        "replay_id": replay_id,
        "replay_path": "",
        "replay_saved": false,
    }
    if replay_recorder != null and replay_recorder.is_recording() and replay_recorder.finish_recording(simulation.state_signature()):
        correlation = TelemetryReplayStore.save(replay_id, replay_recorder.replay_data(), replay_directory)
        if not bool(correlation.get("replay_saved", false)):
            telemetry_service.record_error("REPLAY_SAVE_FAILED", "Replay file could not be saved")
    telemetry_service.end_match(disconnect_reason, simulation, correlation)
    _match_finalized = true
