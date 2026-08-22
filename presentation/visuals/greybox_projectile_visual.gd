# Presentation-only placeholder projectile visual.
class_name GreyboxProjectileVisual
extends Node2D

var projectile_id: StringName = &""
var facing: int = 1
var body_color: Color = Color(0.95, 0.9, 0.35, 1.0)

func configure(id_value: StringName, color_value: Color, scale_value: float) -> void:
    projectile_id = id_value
    body_color = color_value
    scale = Vector2(scale_value, scale_value)
    queue_redraw()

func set_facing(value: int) -> void:
    facing = -1 if value < 0 else 1
    var abs_x := absf(scale.x)
    scale.x = abs_x * facing

func _draw() -> void:
    draw_rect(Rect2(Vector2(-16, -10), Vector2(32, 20)), body_color, true)
