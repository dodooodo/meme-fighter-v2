# Player-facing read-only HUD. It projects authoritative round_controller/timer state through BattleHudViewModel.
class_name BattleHUD
extends Control

@onready var p1_hp_bar: ProgressBar = $P1HP
@onready var p2_hp_bar: ProgressBar = $P2HP
@onready var p1_meter_bar: ProgressBar = $P1Meter
@onready var p2_meter_bar: ProgressBar = $P2Meter
@onready var p1_name_label: Label = $P1Name
@onready var p2_name_label: Label = $P2Name
@onready var p1_hp_label: Label = $P1HPText
@onready var p2_hp_label: Label = $P2HPText
@onready var p1_wins_label: Label = $P1Wins
@onready var p2_wins_label: Label = $P2Wins
@onready var timer_label: Label = $Timer
@onready var round_label: Label = $RoundState
@onready var training_label: Label = $Training

var view_model: BattleHudViewModel = BattleHudViewModel.new()
var p1_presentation: CharacterPresentationData
var p2_presentation: CharacterPresentationData

func configure(p1_data: CharacterPresentationData, p2_data: CharacterPresentationData) -> void:
    p1_presentation = p1_data
    p2_presentation = p2_data

func update_from_simulation(simulation: BattleSimulation) -> void:
    if simulation == null:
        return
    view_model.update_from(simulation, p1_presentation, p2_presentation)
    p1_hp_bar.max_value = view_model.p1_max_hp
    p2_hp_bar.max_value = view_model.p2_max_hp
    p1_hp_bar.value = view_model.p1_hp
    p2_hp_bar.value = view_model.p2_hp
    p1_meter_bar.max_value = 100
    p2_meter_bar.max_value = 100
    p1_meter_bar.value = view_model.p1_meter
    p2_meter_bar.value = view_model.p2_meter
    p1_name_label.text = view_model.p1_name
    p2_name_label.text = view_model.p2_name
    p1_hp_label.text = "%d / %d" % [view_model.p1_hp, view_model.p1_max_hp]
    p2_hp_label.text = "%d / %d" % [view_model.p2_hp, view_model.p2_max_hp]
    p1_wins_label.text = "Wins %d" % view_model.p1_wins
    p2_wins_label.text = "Wins %d" % view_model.p2_wins
    timer_label.text = view_model.timer_text
    round_label.text = "%s | %s" % [view_model.round_text, view_model.state_text]
    training_label.visible = view_model.training
    training_label.text = "TRAINING" if view_model.training else ""
