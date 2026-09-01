# Read-only normalized input display and Training control legend.
class_name TrainingOverlay
extends Control

@onready var controls_label: Label = $Panel/Layout/Controls
@onready var guard_label: Label = $Panel/Layout/GuardMode
@onready var p1_input_label: Label = $Panel/Layout/Inputs/P1Input
@onready var p2_input_label: Label = $Panel/Layout/Inputs/P2Input

var formatter := InputDisplayFormatter.new()
var dummy_source: TrainingDummyInputSource
var training_controller: TrainingController

func configure(mode: int, source: TrainingDummyInputSource, controller: TrainingController = null) -> void:
    visible = mode in [BattleMode.Mode.TRAINING, BattleMode.Mode.TUTORIAL]
    dummy_source = source
    training_controller = controller
    controls_label.visible = mode == BattleMode.Mode.TRAINING
    guard_label.visible = mode == BattleMode.Mode.TRAINING
    _refresh_guard_label()

func update_from_simulation(simulation: BattleSimulation) -> void:
    if not visible or simulation == null:
        return
    p1_input_label.text = "P1  %s" % formatter.format(simulation.fighter_a.input_history.latest())
    p2_input_label.text = "P2  %s" % formatter.format(simulation.fighter_b.input_history.latest())

func refresh_guard_mode() -> void:
    _refresh_guard_label()

func _refresh_guard_label() -> void:
    var mode_name := "STAND"
    if dummy_source != null:
        mode_name = dummy_source.mode_name()
    var hp_mode := "∞HP" if training_controller != null and training_controller.infinite_hp else "HP"
    var meter_mode := "∞METER" if training_controller != null and training_controller.infinite_meter else "METER"
    guard_label.text = "DUMMY / %s    %s    %s" % [mode_name, hp_mode, meter_mode]
