# Deterministic value snapshot for one InputFrame. Contains primitives only.
class_name InputFrameSnapshot
extends RefCounted

var frame_number: int = 0
var direction_x: int = 0
var direction_y: int = 0
var held_bits: int = 0
var pressed_bits: int = 0
var released_bits: int = 0

static func from_frame(frame: InputFrame) -> InputFrameSnapshot:
    if frame == null:
        return null
    var result := InputFrameSnapshot.new()
    result.frame_number = frame.frame_number
    result.direction_x = frame.direction_x
    result.direction_y = frame.direction_y
    result.held_bits = frame.held_bits
    result.pressed_bits = frame.pressed_bits
    result.released_bits = frame.released_bits
    return result

func to_frame() -> InputFrame:
    return InputFrame.new(frame_number, direction_x, direction_y, held_bits, pressed_bits, released_bits)
