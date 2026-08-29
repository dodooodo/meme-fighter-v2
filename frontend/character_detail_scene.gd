# Character movelist screen: pick a character, pick a move, watch it play.
#
# The preview is the character's own fighter visual in preview mode, so pivot,
# scale, and the built frames are what a match would show. Frontend-only: no
# BattleSimulation, no combat rules, no tooling joins.
extends Control

const MODE_SELECT_SCENE := "res://frontend/mode_select_scene.tscn"
const PREVIEW_SPEED_SCALE := 1.0
const THUMBNAIL_SIZE := Vector2(76, 76)
const THUMBNAIL_IDLE := Color(0.62, 0.62, 0.62, 1.0)
const THUMBNAIL_CURRENT := Color(1.0, 1.0, 1.0, 1.0)

@onready var character_select: OptionButton = $Root/Header/CharacterSelect
@onready var back_button: Button = $Root/Header/Back
@onready var move_list: ItemList = $Root/Body/MoveList
@onready var preview_host: SubViewport = $Root/Body/PreviewPanel/Preview/Viewport
@onready var move_title: Label = $Root/Body/PreviewPanel/MoveTitle
@onready var move_stats: Label = $Root/Body/PreviewPanel/MoveStats
@onready var move_notice: Label = $Root/Body/PreviewPanel/MoveNotice
@onready var play_pause_button: Button = $Root/Body/PreviewPanel/Transport/PlayPause
@onready var prev_frame_button: Button = $Root/Body/PreviewPanel/Transport/PrevFrame
@onready var next_frame_button: Button = $Root/Body/PreviewPanel/Transport/NextFrame
@onready var frame_counter: Label = $Root/Body/PreviewPanel/Transport/FrameCounter
@onready var frame_strip: HBoxContainer = $Root/Body/PreviewPanel/FrameStrip/Frames

var roster := CharacterSelectModel.new()
var detail := CharacterDetailModel.new()

var _visual: FighterVisual = null
var _selected_move: int = -1
var _frame_buttons: Array[Button] = []

func _ready() -> void:
    back_button.pressed.connect(_on_back)
    character_select.item_selected.connect(_on_character_selected)
    move_list.item_selected.connect(_on_move_selected)
    play_pause_button.pressed.connect(_on_play_pause)
    prev_frame_button.pressed.connect(_step_frame.bind(-1))
    next_frame_button.pressed.connect(_step_frame.bind(1))

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
    var sprite := _animation_sprite()
    if sprite == null:
        return
    if not sprite.animation_finished.is_connected(_on_preview_animation_finished):
        sprite.animation_finished.connect(_on_preview_animation_finished)
    if not sprite.frame_changed.is_connected(_sync_transport):
        sprite.frame_changed.connect(_sync_transport)

func _play(animation_key: StringName) -> void:
    if _visual == null:
        return
    if _visual.has_method("set_preview_mode"):
        _visual.set_preview_mode(true, PREVIEW_SPEED_SCALE)
    _visual.play_animation(animation_key)
    _rebuild_frame_strip()
    _sync_transport()

# Attack animations are authored non-looping because a match drives their frames
# from the move timeline. This screen has no match to drive them, so a move would
# otherwise play once and freeze on its last frame. Replaying on finish loops
# every move without editing the shared SpriteFrames, which the game also uses.
func _on_preview_animation_finished() -> void:
    var sprite := _animation_sprite()
    if sprite == null or sprite.animation == &"":
        return
    sprite.frame = 0
    sprite.play(sprite.animation)

# Read through get() so any FighterVisual implementation without an
# AnimatedSprite2D simply does not loop rather than breaking the screen.
func _animation_sprite() -> AnimatedSprite2D:
    if _visual == null:
        return null
    return _visual.get("sprite") as AnimatedSprite2D


# --- frame inspection --------------------------------------------------------

# One thumbnail per built frame, so a contributor can see every image in the
# animation at once and jump straight to the one they want to examine.
func _rebuild_frame_strip() -> void:
    for button: Button in _frame_buttons:
        button.queue_free()
    _frame_buttons.clear()

    var sprite := _animation_sprite()
    var frames := _frame_count()
    if sprite == null or frames == 0:
        return
    var key := sprite.animation
    for index in range(frames):
        var button := Button.new()
        button.icon = sprite.sprite_frames.get_frame_texture(key, index)
        button.expand_icon = true
        button.custom_minimum_size = THUMBNAIL_SIZE
        button.tooltip_text = "Frame %d of %d" % [index + 1, frames]
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_show_frame.bind(index))
        frame_strip.add_child(button)
        _frame_buttons.append(button)

func _on_play_pause() -> void:
    var sprite := _animation_sprite()
    if sprite == null:
        return
    if sprite.is_playing():
        sprite.pause()
    else:
        sprite.play()
    _sync_transport()

# Stepping implies inspecting one frame, so it pauses rather than fighting
# playback. Wraps at both ends so the last frame steps back to the first.
func _step_frame(delta: int) -> void:
    var frames := _frame_count()
    if frames == 0:
        return
    _show_frame(wrapi(_animation_sprite().frame + delta, 0, frames))

func _show_frame(index: int) -> void:
    var sprite := _animation_sprite()
    if sprite == null or _frame_count() == 0:
        return
    if sprite.is_playing():
        sprite.pause()
    sprite.frame = index
    _sync_transport()

func _sync_transport() -> void:
    var sprite := _animation_sprite()
    var frames := _frame_count()
    var playing := sprite != null and sprite.is_playing()
    play_pause_button.text = "PAUSE" if playing else "PLAY"
    play_pause_button.disabled = sprite == null or frames == 0
    prev_frame_button.disabled = frames == 0
    next_frame_button.disabled = frames == 0
    if sprite == null or frames == 0:
        frame_counter.text = ""
        return
    frame_counter.text = "Frame %d / %d   ·   %s" % [sprite.frame + 1, frames, String(sprite.animation)]
    for index in range(_frame_buttons.size()):
        _frame_buttons[index].modulate = THUMBNAIL_CURRENT if index == sprite.frame else THUMBNAIL_IDLE

func _frame_count() -> int:
    var sprite := _animation_sprite()
    if sprite == null or sprite.sprite_frames == null:
        return 0
    var key := sprite.animation
    if key == &"" or not sprite.sprite_frames.has_animation(key):
        return 0
    return sprite.sprite_frames.get_frame_count(key)

func _clear_preview() -> void:
    for button: Button in _frame_buttons:
        button.queue_free()
    _frame_buttons.clear()
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
