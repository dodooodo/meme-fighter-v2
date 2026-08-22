# Responsibility: Immutable-style contextual gameplay command snapshot created for one simulation frame.
# Owns: requested action button, source frame, world direction, facing-at-request, forward/back context.
# Does NOT own: input devices, buffer expiry, state legality, MoveData, fighter pointers, collision, presentation.
# Dependencies: InputFrame action identifiers only.
class_name ActionIntent
extends RefCounted

var action_button: int = 0
var source_frame: int = 0
var direction_x: int = 0
var direction_y: int = 0
var facing_at_request: int = 1
var forward_held: bool = false
var back_held: bool = false

func _init(
    p_action_button: int = 0,
    p_source_frame: int = 0,
    p_direction_x: int = 0,
    p_direction_y: int = 0,
    p_facing_at_request: int = 1
) -> void:
    action_button = p_action_button
    source_frame = p_source_frame
    direction_x = clampi(p_direction_x, -1, 1)
    direction_y = clampi(p_direction_y, -1, 1)
    facing_at_request = -1 if p_facing_at_request < 0 else 1
    forward_held = direction_x != 0 and direction_x == facing_at_request
    back_held = direction_x != 0 and direction_x == -facing_at_request

static func from_input_frame(frame: InputFrame, facing: int, p_action_button: int) -> ActionIntent:
    return ActionIntent.new(
        p_action_button,
        frame.frame_number,
        frame.direction_x,
        frame.direction_y,
        facing
    )

func copy() -> ActionIntent:
    return ActionIntent.new(
        action_button,
        source_frame,
        direction_x,
        direction_y,
        facing_at_request
    )
