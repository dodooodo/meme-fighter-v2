# Deterministic training dummy policy. It produces canonical InputFrames only.
class_name TrainingDummyInputSource
extends InputSource

enum GuardMode {
    OFF,
    STANDING,
    CROUCHING,
}

var _guard_mode: GuardMode = GuardMode.OFF
var _previous_held_bits: int = 0

func set_guard_mode(value: int) -> void:
    _guard_mode = clampi(value, GuardMode.OFF, GuardMode.CROUCHING)

func guard_mode() -> int:
    return _guard_mode

func cycle_guard_mode() -> int:
    set_guard_mode((_guard_mode + 1) % GuardMode.size())
    return _guard_mode

func sample(frame_number: int) -> InputFrame:
    var held := InputFrame.InputButton.GUARD if _guard_mode != GuardMode.OFF else 0
    var pressed := held & ~_previous_held_bits
    var released := _previous_held_bits & ~held
    _previous_held_bits = held
    var direction_y := -1 if _guard_mode == GuardMode.CROUCHING else 0
    return InputFrame.new(frame_number, 0, direction_y, held, pressed, released)

func reset() -> void:
    _previous_held_bits = 0
