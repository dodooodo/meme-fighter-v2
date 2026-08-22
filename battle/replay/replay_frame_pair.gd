# Responsibility: One absolute authoritative simulation frame of normalized P1/P2 replay input.
# Owns: frame number and copied InputFrame values only.
# Does NOT own: ActionIntent, Fighter state, HP, meter, projectile state, presentation.
class_name ReplayFramePair
extends RefCounted

var frame_number: int = 0
var p1_input: InputFrame
var p2_input: InputFrame

func _init(p_frame_number: int = 0, p_p1_input: InputFrame = null, p_p2_input: InputFrame = null) -> void:
    frame_number = p_frame_number
    p1_input = p_p1_input.copy() if p_p1_input != null else InputFrame.neutral(p_frame_number)
    p2_input = p_p2_input.copy() if p_p2_input != null else InputFrame.neutral(p_frame_number)

func copy() -> ReplayFramePair:
    return ReplayFramePair.new(frame_number, p1_input, p2_input)

func is_valid() -> bool:
    if frame_number <= 0 or p1_input == null or p2_input == null:
        return false
    if p1_input.frame_number != frame_number or p2_input.frame_number != frame_number:
        return false
    return _input_valid(p1_input) and _input_valid(p2_input)

static func _input_valid(frame: InputFrame) -> bool:
    if frame.direction_x < -1 or frame.direction_x > 1 or frame.direction_y < -1 or frame.direction_y > 1:
        return false
    if frame.held_bits < 0 or frame.pressed_bits < 0 or frame.released_bits < 0:
        return false
    if (frame.held_bits & ~ReplayFormat.VALID_INPUT_MASK) != 0:
        return false
    if (frame.pressed_bits & ~ReplayFormat.VALID_INPUT_MASK) != 0:
        return false
    if (frame.released_bits & ~ReplayFormat.VALID_INPUT_MASK) != 0:
        return false
    return true
