# Guided tutorial UI. It observes normalized input and never mutates gameplay.
class_name TutorialOverlay
extends Control

@onready var step_label: Label = $Card/Layout/Step
@onready var title_label: Label = $Card/Layout/Title
@onready var prompt_label: Label = $Card/Layout/Prompt

var model := TutorialLessonModel.new()
var _last_observed_frame: int = -1

func configure(mode: int) -> void:
    visible = mode == BattleMode.Mode.TUTORIAL
    reset()

func reset() -> void:
    model.reset()
    _last_observed_frame = -1
    _refresh()

func update_from_simulation(simulation: BattleSimulation) -> void:
    if not visible or simulation == null:
        return
    var frame := simulation.fighter_a.input_history.latest()
    if frame != null and frame.frame_number != _last_observed_frame:
        _last_observed_frame = frame.frame_number
        model.observe_input(frame, simulation.fighter_a.movement_motor.facing)
    _refresh()

func _refresh() -> void:
    if not is_node_ready():
        return
    step_label.text = "FIRST FIGHT  /  %s" % model.progress_text()
    title_label.text = model.current_title()
    prompt_label.text = model.current_prompt()
