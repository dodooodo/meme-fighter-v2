# Player-facing Stage A launcher. Keeps the original selector UI while loading
# fighter data exclusively through manifest-backed character packages.
class_name ModeSelectScene
extends Control

const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")
const CHARACTER_DETAIL_SCENE := preload("res://frontend/character_detail_scene.tscn")

@onready var p1_select: OptionButton = $Center/VBox/CharacterSelectors/P1Select
@onready var p2_select: OptionButton = $Center/VBox/CharacterSelectors/P2Select
@onready var vs_cpu_button: Button = $Center/VBox/Buttons/VsCpu
@onready var local_button: Button = $Center/VBox/Buttons/Local2P
@onready var training_button: Button = $Center/VBox/ExtraModes/Training
@onready var tutorial_button: Button = $Center/VBox/ExtraModes/Tutorial
@onready var move_list_button: Button = $Center/VBox/ExtraModes/MoveList

var model := CharacterSelectModel.new()

func _ready() -> void:
    var loaded := model.load_builtin_roster()
    _set_actions_enabled(loaded and model.count() >= 1)
    if not loaded:
        push_error("Character packages could not be loaded")
        return
    _populate_roster()
    vs_cpu_button.pressed.connect(_start_battle.bind(BattleMode.Mode.VS_CPU))
    local_button.pressed.connect(_start_battle.bind(BattleMode.Mode.LOCAL_2P))
    training_button.pressed.connect(_start_battle.bind(BattleMode.Mode.TRAINING))
    tutorial_button.pressed.connect(_start_battle.bind(BattleMode.Mode.TUTORIAL))
    move_list_button.pressed.connect(_open_move_list)
    vs_cpu_button.grab_focus()

func _populate_roster() -> void:
    p1_select.clear()
    p2_select.clear()
    for index in range(model.count()):
        var manifest := model.manifest(index)
        var label := "%02d  %s" % [index + 1, manifest.display_name]
        p1_select.add_item(label, index)
        p2_select.add_item(label, index)
    p1_select.select(0)
    p2_select.select(1 if model.count() > 1 else 0)

func _start_battle(mode: int) -> void:
    var p1 := model.manifest(p1_select.get_selected_id())
    var p2 := model.manifest(p2_select.get_selected_id())
    if p1 == null or p2 == null or not p1.available or not p2.available:
        push_error("Character package selection is invalid")
        return
    var battle := BATTLE_SCENE.instantiate() as BattleScene
    if battle == null:
        push_error("BattleScene could not be instantiated")
        return
    battle.battle_mode = mode
    battle.character_a_data = p1.gameplay_resource
    battle.character_b_data = p2.gameplay_resource
    battle.character_a_presentation = p1.presentation_resource
    battle.character_b_presentation = p2.presentation_resource
    battle.match_rules_data = MatchRulesData.training_defaults() if BattleMode.uses_training_rules(mode) else MatchRulesData.versus_defaults()
    var tree := get_tree()
    tree.root.add_child(battle)
    tree.current_scene = battle
    queue_free()

# Opens the movelist on whichever character P1 currently has selected.
func _open_move_list() -> void:
    var selected := model.manifest(p1_select.get_selected_id())
    var detail := CHARACTER_DETAIL_SCENE.instantiate()
    if detail == null:
        push_error("Character detail scene could not be instantiated")
        return
    var tree := get_tree()
    tree.root.add_child(detail)
    tree.current_scene = detail
    if selected != null and detail.has_method("focus_character"):
        detail.focus_character(selected.id)
    queue_free()

func _set_actions_enabled(enabled: bool) -> void:
    vs_cpu_button.disabled = not enabled
    local_button.disabled = not enabled
    training_button.disabled = not enabled
    tutorial_button.disabled = not enabled
    move_list_button.disabled = not enabled
