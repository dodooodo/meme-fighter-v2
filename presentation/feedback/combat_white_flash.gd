# Brief screen-space presentation flash. It owns no simulation or gameplay timing.
class_name CombatWhiteFlash
extends CanvasLayer

var remaining_seconds: float = 0.0
var initial_seconds: float = 0.0
var peak_alpha: float = 0.0
var overlay: ColorRect

func configure(alpha_value: float, lifetime_seconds: float) -> void:
    peak_alpha = clampf(alpha_value, 0.0, 1.0)
    remaining_seconds = maxf(0.01, lifetime_seconds)
    initial_seconds = remaining_seconds
    layer = 90
    overlay = ColorRect.new()
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.color = Color(1.0, 1.0, 1.0, peak_alpha)
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
    remaining_seconds = maxf(0.0, remaining_seconds - delta)
    if overlay != null:
        overlay.color.a = peak_alpha * (remaining_seconds / initial_seconds)
    if remaining_seconds <= 0.0:
        queue_free()
