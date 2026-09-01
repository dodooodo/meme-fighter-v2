# Player-facing Stage A launcher. RosterRegistry-backed frontend entries carry
# the exact active gameplay and presentation resources into BattleScene.
class_name ModeSelectScene
extends Control

const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")
const MENU_AUDIO_PRESENTER := preload("res://presentation/audio/menu_audio_presenter.gd")

@onready var p1_select: OptionButton = $Center/VBox/CharacterSelectors/P1Select
@onready var p2_select: OptionButton = $Center/VBox/CharacterSelectors/P2Select
@onready var vs_cpu_button: Button = $Center/VBox/Buttons/VsCpu
@onready var local_button: Button = $Center/VBox/Buttons/Local2P
@onready var training_button: Button = $Center/VBox/ExtraModes/Training
@onready var tutorial_button: Button = $Center/VBox/ExtraModes/Tutorial
@onready var menu_audio: Node = $MenuAudio
@onready var selection_summary: Label = $Center/VBox/SelectionSummary
@onready var selection_hint: Label = $Center/VBox/SelectionHint

var model := CharacterSelectModel.new()

func _ready() -> void:
    var loaded := model.load_builtin_roster()
    _set_actions_enabled(loaded and model.count() >= 1)
    if not loaded:
        push_error("Playable roster could not be loaded")
        return
    _populate_roster()
    vs_cpu_button.pressed.connect(_start_battle.bind(BattleMode.Mode.VS_CPU))
    local_button.pressed.connect(_start_battle.bind(BattleMode.Mode.LOCAL_2P))
    training_button.pressed.connect(_start_battle.bind(BattleMode.Mode.TRAINING))
    tutorial_button.pressed.connect(_start_battle.bind(BattleMode.Mode.TUTORIAL))
    p1_select.item_selected.connect(_refresh_selection_summary)
    p2_select.item_selected.connect(_refresh_selection_summary)
    _refresh_selection_summary()
    p1_select.grab_focus()

func _populate_roster() -> void:
    p1_select.clear()
    p2_select.clear()
    for index in range(model.count()):
        var roster_entry := model.entry(index)
        var name := String(roster_entry["display_name"])
        p1_select.add_item("P1  %02d  %s" % [index + 1, name], index)
        p2_select.add_item("P2  %02d  %s" % [index + 1, name], index)
        p1_select.set_item_metadata(index, roster_entry["id"])
        p2_select.set_item_metadata(index, roster_entry["id"])
    p1_select.select(0)
    p2_select.select(1 if model.count() > 1 else 0)

func _refresh_selection_summary(_selected_index: int = -1) -> void:
    var p1 := model.entry(p1_select.get_selected_id())
    var p2 := model.entry(p2_select.get_selected_id())
    if p1.is_empty() or p2.is_empty():
        selection_summary.text = "SELECT TWO FIGHTERS"
        selection_hint.text = "Use Left / Right or click a roster list. Mirror matches are allowed."
        return
    selection_summary.text = "P1 READY: %s                         P2 READY: %s" % [String(p1["display_name"]), String(p2["display_name"])]
    selection_hint.text = "Both selections are confirmed here. Choose a mode below to start. Mirror matches are allowed."

func _start_battle(mode: int) -> void:
    var p1 := model.entry(p1_select.get_selected_id())
    var p2 := model.entry(p2_select.get_selected_id())
    if p1.is_empty() or p2.is_empty():
        push_error("Playable roster selection is invalid")
        return
    if menu_audio != null:
        menu_audio.present_confirm()
    var battle := BATTLE_SCENE.instantiate() as BattleScene
    if battle == null:
        push_error("BattleScene could not be instantiated")
        return
    battle.battle_mode = mode
    battle.character_a_data = p1["character"] as CharacterData
    battle.character_b_data = p2["character"] as CharacterData
    battle.character_a_presentation = p1["presentation"] as CharacterPresentationData
    battle.character_b_presentation = p2["presentation"] as CharacterPresentationData
    battle.match_rules_data = MatchRulesData.training_defaults() if BattleMode.uses_training_rules(mode) else MatchRulesData.versus_defaults()
    var tree := get_tree()
    tree.root.add_child(battle)
    tree.current_scene = battle
    queue_free()

func _set_actions_enabled(enabled: bool) -> void:
    vs_cpu_button.disabled = not enabled
    local_button.disabled = not enabled
    training_button.disabled = not enabled
    tutorial_button.disabled = not enabled
