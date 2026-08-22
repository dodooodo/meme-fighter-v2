# Presentation-only procedural impact burst. Lifetime uses render delta; no gameplay mutation.
class_name PlaceholderCombatVfx
extends Node2D

var effect_color: Color = Color.WHITE
var radius: float = 16.0
var intensity: float = 1.0
var ray_count: int = 4
var remaining_seconds: float = 0.18
var initial_seconds: float = 0.18

func configure(color_value: Color, radius_value: float, intensity_value: float = 1.0, rays: int = 4, lifetime: float = 0.18) -> void:
    effect_color = color_value
    radius = radius_value
    intensity = maxf(0.25, intensity_value)
    ray_count = clampi(rays, 0, 12)
    remaining_seconds = maxf(0.05, lifetime)
    initial_seconds = remaining_seconds
    queue_redraw()

func _process(delta: float) -> void:
    remaining_seconds -= delta
    modulate.a = clampf(remaining_seconds / initial_seconds, 0.0, 1.0)
    scale = Vector2.ONE * (1.0 + (1.0 - modulate.a) * 0.22 * intensity)
    if remaining_seconds <= 0.0:
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, radius, Color(effect_color.r, effect_color.g, effect_color.b, effect_color.a * 0.52))
    draw_arc(Vector2.ZERO, radius * 1.15, 0.0, TAU, 28, effect_color, maxf(1.0, 2.0 * intensity))
    draw_circle(Vector2.ZERO, maxf(2.0, radius * 0.30), Color(1, 1, 1, 0.92))
    if ray_count <= 0:
        return
    for i in range(ray_count):
        var angle := TAU * float(i) / float(ray_count) + 0.17
        var inner := Vector2(cos(angle), sin(angle)) * radius * 0.62
        var outer := Vector2(cos(angle), sin(angle)) * radius * (1.28 + 0.05 * float(i % 3))
        draw_line(inner, outer, effect_color, maxf(1.0, 1.6 * intensity))
