# Character movelist screen: pick a character, pick a move, watch it play.
#
# The preview is the character's own fighter visual in preview mode, so pivot,
# scale, and the built frames are what a match would show. Frontend-only: no
# BattleSimulation, no combat rules, no tooling joins.
extends Control

const MODE_SELECT_SCENE := "res://frontend/mode_select_scene.tscn"
const PREVIEW_SPEED_SCALE := 1.0
const PREVIEW_FILL := 0.86
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
var _content_rects: Dictionary = {}
var _preview_extent := Vector2.ZERO

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
    if _visual.has_method("set_preview_mode"):
        _visual.set_preview_mode(true, PREVIEW_SPEED_SCALE)
    var sprite := _animation_sprite()
    if sprite == null:
        return
    if not sprite.animation_finished.is_connected(_on_preview_animation_finished):
        sprite.animation_finished.connect(_on_preview_animation_finished)
    if not sprite.frame_changed.is_connected(_sync_transport):
        sprite.frame_changed.connect(_sync_transport)
    if not preview_host.size_changed.is_connected(_fit_preview):
        preview_host.size_changed.connect(_fit_preview)
    _preview_extent = _character_extent(sprite)

func _play(animation_key: StringName) -> void:
    if _visual == null:
        return
    if _visual.has_method("set_preview_mode"):
        _visual.set_preview_mode(true, PREVIEW_SPEED_SCALE)
    _visual.play_animation(animation_key)
    _rebuild_frame_strip()
    _fit_preview()
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



# --- framing -----------------------------------------------------------------

# Characters are authored at wildly different pixel sizes and anchored at the
# feet, so a fixed placement leaves some floating in empty space and crops
# others. Measure the animation's own extent and scale it to fill the preview.
#
# Measured in the visual's local space, which excludes the visual's own scale,
# so the fit does not compound across calls.
func _fit_preview() -> void:
    var sprite := _animation_sprite()
    if _visual == null or sprite == null:
        return
    var viewport_size := Vector2(preview_host.size)
    if _preview_extent.x <= 0.0 or _preview_extent.y <= 0.0:
        return
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return

    var base_scale := 1.0
    var presentation_data := detail.presentation()
    if presentation_data != null:
        base_scale = maxf(0.001, presentation_data.visual_scale)
    var available := viewport_size * PREVIEW_FILL
    var fit := minf(
        available.x / (_preview_extent.x * base_scale),
        available.y / (_preview_extent.y * base_scale)
    )
    _visual.set_visual_scale_multiplier(fit)

    # The visual's origin is the authored feet pivot, not the middle of the art,
    # so centring means offsetting by where this animation actually sits around
    # it. Frames drift from the pivot by different amounts per animation.
    var bounds := _animation_bounds(sprite)
    if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
        return
    _visual.position = viewport_size * 0.5 - bounds.get_center() * base_scale * fit

# Scale is taken from the character's largest drawn frame rather than from each
# animation, so one character keeps one scale across its whole movelist: a jab
# still reads as smaller than an ultimate, and selecting a move does not resize
# the character. Needs no pivot, so it never disturbs playback.
func _character_extent(sprite: AnimatedSprite2D) -> Vector2:
    var sprite_frames := sprite.sprite_frames
    if sprite_frames == null:
        return Vector2.ZERO
    var extent := Vector2.ZERO
    var frame_scale := sprite.scale.abs()
    for key: StringName in sprite_frames.get_animation_names():
        for index in range(sprite_frames.get_frame_count(key)):
            var texture := sprite_frames.get_frame_texture(key, index)
            if texture != null:
                # A blank frame measures zero and simply contributes nothing.
                extent = extent.max(_content_rect(texture).size * frame_scale)
    return extent

# Union across the selected animation's frames, used for centring only.
func _animation_bounds(sprite: AnimatedSprite2D) -> Rect2:
    var frames := _frame_count()
    if frames == 0:
        return Rect2()
    var restore_frame := sprite.frame
    var was_playing := sprite.is_playing()
    var bounds := Rect2()
    var measured := false
    for index in range(frames):
        # Assigning the frame fires frame_changed, which repositions the sprite
        # on that frame's authored pivot; frame 0 was already positioned by the
        # play_animation call that preceded this.
        if sprite.frame != index:
            sprite.frame = index
        var rect := sprite.transform * _frame_rect(sprite, index)
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue  # blank frame: nothing drawn, nothing to frame around
        bounds = rect if not measured else bounds.merge(rect)
        measured = true
    if sprite.frame != restore_frame:
        sprite.frame = restore_frame
    if was_playing:
        sprite.play()
    else:
        sprite.pause()
    return bounds

# AnimatedSprite2D has no get_rect(); derive it the way it draws, honouring the
# top-left anchoring the production visual relies on.
#
# Frames are built on a square canvas and a character can fill as little as 43%
# of it, so framing by canvas would leave most characters half the size they
# could be. Measure the drawn pixels instead.
func _frame_rect(sprite: AnimatedSprite2D, index: int) -> Rect2:
    var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, index)
    if texture == null:
        return Rect2()
    var origin := sprite.offset
    if sprite.centered:
        origin -= Vector2(texture.get_size()) * 0.5
    var content := _content_rect(texture)
    return Rect2(origin + content.position, content.size)

# Decoding a texture is not free and packages reuse the same frame image across
# animations, so cache by resource path.
#
# A fully transparent frame returns an empty rect and callers skip it. Treating
# it as the full canvas instead would let one blank frame dictate the framing for
# the whole character, which is how salad_cat's blank walk_back frames were
# found. An unreadable image still falls back to the canvas, since that is a
# measurement failure rather than an empty frame.
func _content_rect(texture: Texture2D) -> Rect2:
    var key := texture.resource_path
    if key.is_empty():
        return Rect2(Vector2.ZERO, Vector2(texture.get_size()))
    if _content_rects.has(key):
        return _content_rects[key]
    var image := texture.get_image()
    var rect := Rect2(Vector2.ZERO, Vector2(texture.get_size()))
    if image != null:
        rect = Rect2(image.get_used_rect())
    _content_rects[key] = rect
    return rect

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
