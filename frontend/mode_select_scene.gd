# Player-facing Stage A character select and mode launch scene.
class_name ModeSelectScene
extends Control

const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")
const COLOR_PAPER := Color("f7f2e7")
const COLOR_GOLD := Color("f4b942")
const COLOR_CORAL := Color("ff6b6b")
const COLOR_AQUA := Color("55dde0")

@onready var roster_container: HBoxContainer = $Margin/Layout/Roster
@onready var p1_label: Label = $Margin/Layout/Selection/P1
@onready var p2_label: Label = $Margin/Layout/Selection/P2
@onready var vs_cpu_button: Button = $Margin/Layout/Actions/VsCpu
@onready var local_button: Button = $Margin/Layout/Actions/Local2P
@onready var training_button: Button = $Margin/Layout/Actions/Training
@onready var tutorial_button: Button = $Margin/Layout/Actions/Tutorial
@onready var status_label: Label = $Margin/Layout/Status

var model := CharacterSelectModel.new()
var p1_index: int = 0
var p2_index: int = 1
var _card_panels: Array[PanelContainer] = []

func _ready() -> void:
    var loaded := model.load_builtin_roster()
    _set_actions_enabled(loaded and model.count() >= 1)
    if not loaded:
        status_label.text = "Character packages could not be loaded."
        return
    p2_index = 1 if model.count() > 1 else 0
    _build_roster_cards()
    _refresh_selection()
    vs_cpu_button.pressed.connect(_start_battle.bind(BattleMode.Mode.VS_CPU))
    local_button.pressed.connect(_start_battle.bind(BattleMode.Mode.LOCAL_2P))
    training_button.pressed.connect(_start_battle.bind(BattleMode.Mode.TRAINING))
    tutorial_button.pressed.connect(_start_battle.bind(BattleMode.Mode.TUTORIAL))
    vs_cpu_button.grab_focus()

func _build_roster_cards() -> void:
    for child in roster_container.get_children():
        child.queue_free()
    _card_panels.clear()
    for index in range(model.count()):
        var manifest := model.manifest(index)
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(300, 320)
        card.name = "FighterCard%d" % index
        var content := VBoxContainer.new()
        content.add_theme_constant_override("separation", 8)
        var portrait := TextureRect.new()
        portrait.custom_minimum_size = Vector2(260, 210)
        portrait.texture = manifest.portrait
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var name_label := Label.new()
        name_label.text = manifest.display_name
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 25)
        name_label.add_theme_color_override("font_color", COLOR_PAPER)
        var ready := Label.new()
        ready.text = "●  READY" if manifest.available else "○  UNAVAILABLE"
        ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ready.add_theme_font_size_override("font_size", 12)
        ready.add_theme_color_override("font_color", COLOR_AQUA if manifest.available else COLOR_CORAL)
        var selectors := HBoxContainer.new()
        selectors.alignment = BoxContainer.ALIGNMENT_CENTER
        selectors.add_theme_constant_override("separation", 8)
        var choose_p1 := Button.new()
        choose_p1.text = "CHOOSE P1"
        choose_p1.disabled = not manifest.available
        choose_p1.pressed.connect(_select_fighter.bind(1, index))
        var choose_p2 := Button.new()
        choose_p2.text = "CHOOSE P2"
        choose_p2.disabled = not manifest.available
        choose_p2.pressed.connect(_select_fighter.bind(2, index))
        selectors.add_child(choose_p1)
        selectors.add_child(choose_p2)
        content.add_child(portrait)
        content.add_child(name_label)
        content.add_child(ready)
        content.add_child(selectors)
        card.add_child(content)
        roster_container.add_child(card)
        _card_panels.append(card)

func _select_fighter(player: int, index: int) -> void:
    if model.manifest(index) == null or not model.manifest(index).available:
        return
    if player == 1:
        p1_index = index
    else:
        p2_index = index
    _refresh_selection()

func _refresh_selection() -> void:
    var p1 := model.manifest(p1_index)
    var p2 := model.manifest(p2_index)
    p1_label.text = "P1  /  %s" % (p1.display_name if p1 != null else "—")
    p2_label.text = "P2  /  %s" % (p2.display_name if p2 != null else "—")
    for index in range(_card_panels.size()):
        var style := StyleBoxFlat.new()
        style.bg_color = Color("1c2536")
        style.corner_radius_top_left = 10
        style.corner_radius_top_right = 10
        style.corner_radius_bottom_left = 10
        style.corner_radius_bottom_right = 10
        style.border_width_left = 4
        style.border_width_top = 4
        style.border_width_right = 4
        style.border_width_bottom = 4
        if index == p1_index and index == p2_index:
            style.border_color = COLOR_GOLD
        elif index == p1_index:
            style.border_color = COLOR_CORAL
        elif index == p2_index:
            style.border_color = COLOR_AQUA
        else:
            style.border_color = Color("344056")
        _card_panels[index].add_theme_stylebox_override("panel", style)
    status_label.text = "Same-fighter matches are allowed. P1 uses WASD + U I J K L."

func _start_battle(mode: int) -> void:
    var p1 := model.manifest(p1_index)
    var p2 := model.manifest(p2_index)
    if p1 == null or p2 == null or not p1.available or not p2.available:
        status_label.text = "Choose two available fighters."
        return
    var battle := BATTLE_SCENE.instantiate() as BattleScene
    if battle == null:
        status_label.text = "Battle scene could not be loaded."
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

func _set_actions_enabled(enabled: bool) -> void:
    vs_cpu_button.disabled = not enabled
    local_button.disabled = not enabled
    training_button.disabled = not enabled
    tutorial_button.disabled = not enabled
