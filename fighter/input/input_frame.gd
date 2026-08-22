# Responsibility: One authoritative simulation-frame input snapshot.
# Owns: world direction, action-button held/pressed/released bitsets, frame number.
# Does NOT own: device polling, move recognition, fighter state, jump/crouch gameplay meaning.
# Dependencies: none.
class_name InputFrame
extends RefCounted

enum InputButton {
    LIGHT = 1 << 0,
    HEAVY = 1 << 1,
    GUARD = 1 << 2,
    SPECIAL = 1 << 3,
    ULTIMATE = 1 << 4,
}

var frame_number: int = 0
var direction_x: int = 0
var direction_y: int = 0
var held_bits: int = 0
var pressed_bits: int = 0
var released_bits: int = 0

func _init(
    p_frame_number: int = 0,
    p_direction_x: int = 0,
    p_direction_y: int = 0,
    p_held_bits: int = 0,
    p_pressed_bits: int = 0,
    p_released_bits: int = 0
) -> void:
    frame_number = p_frame_number
    direction_x = clampi(p_direction_x, -1, 1)
    direction_y = clampi(p_direction_y, -1, 1)
    held_bits = p_held_bits
    pressed_bits = p_pressed_bits
    released_bits = p_released_bits

static func neutral(frame: int) -> InputFrame:
    return InputFrame.new(frame)

static func with_light_press(frame: int, direction_x_value: int = 0, direction_y_value: int = 0) -> InputFrame:
    return InputFrame.new(frame, direction_x_value, direction_y_value, InputButton.LIGHT, InputButton.LIGHT, 0)

static func with_heavy_press(frame: int, direction_x_value: int = 0, direction_y_value: int = 0) -> InputFrame:
    return InputFrame.new(frame, direction_x_value, direction_y_value, InputButton.HEAVY, InputButton.HEAVY, 0)

static func with_special_press(frame: int, direction_x_value: int = 0, direction_y_value: int = 0) -> InputFrame:
    return InputFrame.new(frame, direction_x_value, direction_y_value, InputButton.SPECIAL, InputButton.SPECIAL, 0)

static func with_ultimate_press(frame: int, direction_x_value: int = 0, direction_y_value: int = 0) -> InputFrame:
    return InputFrame.new(frame, direction_x_value, direction_y_value, InputButton.ULTIMATE, InputButton.ULTIMATE, 0)

func is_held(button: int) -> bool:
    return (held_bits & button) != 0

func is_pressed(button: int) -> bool:
    return (pressed_bits & button) != 0

func is_released(button: int) -> bool:
    return (released_bits & button) != 0

func copy() -> InputFrame:
    return InputFrame.new(frame_number, direction_x, direction_y, held_bits, pressed_bits, released_bits)
