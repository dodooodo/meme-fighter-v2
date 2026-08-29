# Character movelist screen: pick a character, pick a move, watch it play.
#
# The preview is the character's own fighter visual in preview mode, so pivot,
# scale, and the built frames are what a match would show. Frontend-only: no
# BattleSimulation, no combat rules, no tooling joins.
extends Control

const MODE_SELECT_SCENE := "res://frontend/mode_select_scene.tscn"
const PREVIEW_SPEED_SCALE := 1.0

@onready var character_select: OptionButton = $Root/Header/CharacterSelect
@onready var back_button: Button = $Root/Header/Back
@onready var move_list: ItemList = $Root/Body/MoveList
@onready var preview_host: SubViewport = $Root/Body/PreviewPanel/Preview/Viewport
@onready var move_title: Label = $Root/Body/PreviewPanel/MoveTitle
@onready var move_stats: Label = $Root/Body/PreviewPanel/MoveStats
@onready var move_notice: Label = $Root/Body/PreviewPanel/MoveNotice

var roster := CharacterSelectModel.new()
var detail := CharacterDetailModel.new()

var _visual: FighterVisual = null
var _selected_move: int = -1

func _ready() -> void:
    back_button.pressed.connect(_on_back)
    character_select.item_selected.connect(_on_character_selected)
    move_list.item_selected.connect(_on_move_selected)

    if not roster.load_builtin_roster() or roster.count() == 0:
        move_notice.text = "No character packages available."
        return
    for index in range(roster.count()):
        character_select.add_item(roster.manifest(index).display_name, index)
    character_select.select(0)
    _on_character_selected(0)

# Opened from the mode select screen so it lands on the character already chosen.
func focus_character(character_id: StringName) -> void:
    for index in range(roster.count()):
        if roster.manifest(index).id != character_id:
            continue
        character_select.select(index)
        _on_character_selected(index)
        return

func _on_character_selected(index: int) -> void:
    _clear_preview()
    move_list.clear()
    _selected_move = -1
    move_title.text = ""
    move_stats.text = ""
    move_notice.text = ""

    if not detail.configure(roster.manifest(index)):
        move_notice.text = "This character package has no movelist data."
        return

    for row_index in range(detail.move_count()):
        var row := detail.move_row(row_index)
        var label := String(row["display_name"])
        if not row["has_animation"]:
            label += "   (no animation)"
        move_list.add_item(label)
    _mount_visual()
    if detail.move_count() > 0:
        move_list.select(0)
        _on_move_selected(0)

func _on_move_selected(index: int) -> void:
    var row := detail.move_row(index)
    if row.is_empty():
        return
    _selected_move = index
    move_title.text = "%s   ·   %s" % [String(row["display_name"]), String(row["move_id"])]
    move_stats.text = "Startup %d   Active %d   Recovery %d   Total %d   Damage %d   %s" % [
        row["startup_frames"], row["active_frames"], row["recovery_frames"],
        row["total_frames"], row["damage"], String(row["hit_level"]),
    ]
    # Say so rather than let the substituted animation read as this move's own.
    move_notice.text = "" if row["has_animation"] else "No animation is bound to this move yet; showing the game's fallback."
    _play(row["playback_key"])

func _mount_visual() -> void:
    var scene := detail.fighter_visual_scene()
    if scene == null:
        move_notice.text = "This character has no visual scene."
        return
    _visual = scene.instantiate() as FighterVisual
    if _visual == null:
        return
    _visual.set_character_presentation_data(detail.presentation())
    preview_host.add_child(_visual)
    _visual.position = Vector2(preview_host.size.x * 0.5, preview_host.size.y * 0.92)
    if _visual.has_method("set_preview_mode"):
        _visual.set_preview_mode(true, PREVIEW_SPEED_SCALE)

func _play(animation_key: StringName) -> void:
    if _visual == null:
        return
    _visual.play_animation(animation_key)
    if _visual.has_method("set_preview_mode"):
        _visual.set_preview_mode(true, PREVIEW_SPEED_SCALE)

func _clear_preview() -> void:
    if _visual == null:
        return
    _visual.queue_free()
    _visual = null

func _on_back() -> void:
    _clear_preview()
    get_tree().change_scene_to_file(MODE_SELECT_SCENE)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"ui_cancel"):
        _on_back()
