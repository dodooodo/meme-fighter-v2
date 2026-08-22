# Responsibility: Desktop debug keyboard polling -> canonical InputFrame.
# Owns: key bindings and action-button edge detection.
# Does NOT own: gameplay interpretation or direct fighter actions.
# Dependencies: InputSource, InputFrame, Godot Input singleton.
class_name KeyboardInputSource
extends InputSource

var _up_key: int
var _left_key: int
var _down_key: int
var _right_key: int
var _light_key: int
var _heavy_key: int
var _guard_key: int
var _special_key: int
var _ultimate_key: int
var _previous_held_bits: int = 0

func _init(
    up_key: int,
    left_key: int,
    down_key: int,
    right_key: int,
    light_key: int,
    heavy_key: int,
    guard_key: int,
    special_key: int,
    ultimate_key: int
) -> void:
    _up_key = up_key
    _left_key = left_key
    _down_key = down_key
    _right_key = right_key
    _light_key = light_key
    _heavy_key = heavy_key
    _guard_key = guard_key
    _special_key = special_key
    _ultimate_key = ultimate_key

func sample(frame_number: int) -> InputFrame:
    var left := Input.is_key_pressed(_left_key)
    var right := Input.is_key_pressed(_right_key)
    var up := Input.is_key_pressed(_up_key)
    var down := Input.is_key_pressed(_down_key)
    var direction_x := 0
    var direction_y := 0
    if left != right:
        direction_x = -1 if left else 1
    if up != down:
        direction_y = 1 if up else -1

    var held := compose_action_bits(
        Input.is_key_pressed(_light_key),
        Input.is_key_pressed(_heavy_key),
        Input.is_key_pressed(_guard_key),
        Input.is_key_pressed(_special_key),
        Input.is_key_pressed(_ultimate_key)
    )

    var pressed := held & ~_previous_held_bits
    var released := _previous_held_bits & ~held
    _previous_held_bits = held
    return InputFrame.new(frame_number, direction_x, direction_y, held, pressed, released)

func reset() -> void:
    _previous_held_bits = 0


static func compose_action_bits(light: bool, heavy: bool, guard: bool, special: bool, ultimate: bool) -> int:
    var bits := 0
    if light:
        bits |= InputFrame.InputButton.LIGHT
    if heavy:
        bits |= InputFrame.InputButton.HEAVY
    if guard:
        bits |= InputFrame.InputButton.GUARD
    if special:
        bits |= InputFrame.InputButton.SPECIAL
    if ultimate:
        bits |= InputFrame.InputButton.ULTIMATE
    return bits
