# Development/playtest frontend. Selects any formal roster pair, then chooses input wiring.
class_name ModeSelectScene
extends Control

const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")

@onready var p1_select: OptionButton = $Center/VBox/CharacterSelectors/P1Select
@onready var p2_select: OptionButton = $Center/VBox/CharacterSelectors/P2Select
@onready var vs_cpu_button: Button = $Center/VBox/Buttons/VsCpu
@onready var local_button: Button = $Center/VBox/Buttons/Local2P

func _ready() -> void:
    _populate_roster()
    vs_cpu_button.pressed.connect(func() -> void: _start_battle(BattleMode.Mode.VS_CPU))
    local_button.pressed.connect(func() -> void: _start_battle(BattleMode.Mode.LOCAL_2P))
    vs_cpu_button.grab_focus()

func _populate_roster() -> void:
    p1_select.clear()
    p2_select.clear()
    for index in range(RosterRegistry.count()):
        var item := RosterRegistry.entry(index)
        var label := "%02d  %s" % [index + 1, String(item["name"])]
        p1_select.add_item(label, index)
        p2_select.add_item(label, index)
    p1_select.select(0)
    p2_select.select(1 if RosterRegistry.count() > 1 else 0)

func _start_battle(mode: int) -> void:
    var p1_entry := RosterRegistry.entry(p1_select.get_selected_id())
    var p2_entry := RosterRegistry.entry(p2_select.get_selected_id())
    if p1_entry.is_empty() or p2_entry.is_empty():
        push_error("Roster selection is invalid")
        return
    var battle := BATTLE_SCENE.instantiate() as BattleScene
    if battle == null:
        push_error("BattleScene could not be instantiated")
        return
    battle.battle_mode = mode
    battle.character_a_data = p1_entry["character"] as CharacterData
    battle.character_b_data = p2_entry["character"] as CharacterData
    battle.character_a_presentation = p1_entry["presentation"] as CharacterPresentationData
    battle.character_b_presentation = p2_entry["presentation"] as CharacterPresentationData
    var tree := get_tree()
    tree.root.add_child(battle)
    tree.current_scene = battle
    queue_free()
