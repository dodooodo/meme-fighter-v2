# Presentation-only greybox stage backdrop.
# Fighter/projectile visuals are owned by BattlePresentationController, not this canvas.
class_name BattleView
extends Node2D

var simulation: BattleSimulation

func set_simulation(value: BattleSimulation) -> void:
    simulation = value
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.12, 0.14), true)
    draw_rect(Rect2(0, 560, 1280, 160), Color(0.18, 0.18, 0.20), true)
    draw_line(Vector2(0, 560), Vector2(1280, 560), Color(0.55, 0.55, 0.58), 2.0)
    draw_line(Vector2(80, 80), Vector2(80, 560), Color(0.30, 0.30, 0.34), 2.0)
    draw_line(Vector2(1200, 80), Vector2(1200, 560), Color(0.30, 0.30, 0.34), 2.0)
