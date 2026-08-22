# Replaceable placeholder FighterVisual. Rendering never feeds gameplay geometry.
class_name GreyboxFighterVisual
extends FighterVisual

var body_color: Color = Color(0.55, 0.7, 0.95, 1.0)

func set_character_presentation_data(data: CharacterPresentationData) -> void:
    super.set_character_presentation_data(data)
    if data != null:
        body_color = data.placeholder_color
    queue_redraw()

func play_animation(animation_key: StringName) -> void:
    super.play_animation(animation_key)
    queue_redraw()

func _draw() -> void:
    # Feet-center local origin: body extends upward from y=0.
    var color := body_color
    match current_animation_key:
        &"ko":
            color = body_color.darkened(0.65)
        &"hitstun", &"blockstun":
            color = body_color.lightened(0.2)
    draw_rect(Rect2(Vector2(-28, -150), Vector2(56, 150)), color, true)
    draw_line(Vector2(0, -115), Vector2(34 * current_facing, -115), Color.WHITE, 4.0)
    draw_string(ThemeDB.fallback_font, Vector2(-52, -164), String(current_animation_key), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
