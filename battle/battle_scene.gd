# Responsibility: Scene-level wiring between fixed gameplay simulation and one-way presentation.
# Owns: render scheduler, match-mode InputSource wiring, presentation configuration and event draining.
# Does NOT own: combat rules, collision, HP/meter mutation, round authority, animation-driven gameplay.
class_name BattleScene
extends Node

var simulation: BattleSimulation
var clock: SimulationClock = SimulationClock.new()
var frame_stepper: FrameStepper = FrameStepper.new()
var battle_mode: int = BattleMode.Mode.LOCAL_2P
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
    debug_overlay.set_frame_stepper(frame_stepper)
    debug_overlay.set_presentation_controller(presentation_controller)
    _reset_battle()

func _process(delta: float) -> void:
    if simulation == null:
        return
    var ticks := frame_stepper.consume_ticks(clock, delta)
    for _i in range(ticks):
        simulation.sample_and_simulate_frame()
        presentation_controller.consume_events(simulation.drain_events())
    presentation_controller.sync_from_simulation()
    debug_overlay.update_from_simulation(simulation)

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
    simulation.combat_logger.enabled = OS.is_debug_build()
    clock.reset()
    frame_stepper.reset()
    battle_view.set_simulation(simulation)
    hitbox_debugger.set_simulation(simulation)
    mode_label.text = "%s%s" % [BattleMode.display_name(battle_mode), " | P2 [CPU]" if battle_mode == BattleMode.Mode.VS_CPU else ""]
    if not presentation_controller.configure(simulation, character_a_presentation, character_b_presentation, hud, round_overlay):
        push_error("Battle presentation configuration failed; simulation remains independently valid")
    presentation_controller.consume_events(simulation.drain_events())
    debug_overlay.update_from_simulation(simulation)
