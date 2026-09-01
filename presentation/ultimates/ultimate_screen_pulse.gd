# Generic full-screen spectacle pulse for an already-authoritative Ultimate or
# Finisher event. Render delta only; it cannot pause or alter BattleSimulation.
class_name UltimateScreenPulse
extends ColorRect

var remaining_seconds: float = 0.32
var initial_seconds: float = 0.32
var peak_alpha: float = 0.22

func configure(color_value: Color, duration_seconds: float = 0.32, alpha_value: float = 0.22) -> void:
    color = Color(color_value.r, color_value.g, color_value.b, clampf(alpha_value, 0.0, 0.5))
    peak_alpha = color.a
    initial_seconds = maxf(0.05, duration_seconds)
    remaining_seconds = initial_seconds
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
    remaining_seconds = maxf(0.0, remaining_seconds - delta)
    color.a = peak_alpha * (remaining_seconds / initial_seconds)
    if remaining_seconds <= 0.0:
        queue_free()
