# Presentation-only formatter for normalized simulation InputFrames.
class_name InputDisplayFormatter
extends RefCounted

const BUTTONS: Array[Dictionary] = [
    {"bit": InputFrame.InputButton.LIGHT, "label": "L"},
    {"bit": InputFrame.InputButton.HEAVY, "label": "H"},
    {"bit": InputFrame.InputButton.GUARD, "label": "G"},
    {"bit": InputFrame.InputButton.SPECIAL, "label": "S"},
    {"bit": InputFrame.InputButton.ULTIMATE, "label": "U"},
]

func format(frame: InputFrame) -> String:
    if frame == null:
        return "·"
    var tokens := PackedStringArray([_direction_token(frame.direction_x, frame.direction_y)])
    for item: Dictionary in BUTTONS:
        if frame.is_held(int(item["bit"])):
            tokens.append(String(item["label"]) + ("!" if frame.is_pressed(int(item["bit"])) else ""))
    return "  ".join(tokens)

func _direction_token(x: int, y: int) -> String:
    var key := Vector2i(clampi(x, -1, 1), clampi(y, -1, 1))
    var arrows := {
        Vector2i(-1, 1): "↖", Vector2i(0, 1): "↑", Vector2i(1, 1): "↗",
        Vector2i(-1, 0): "←", Vector2i(0, 0): "·", Vector2i(1, 0): "→",
        Vector2i(-1, -1): "↙", Vector2i(0, -1): "↓", Vector2i(1, -1): "↘",
    }
    return String(arrows.get(key, "·"))
