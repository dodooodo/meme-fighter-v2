# Deterministic value snapshot for one buffered ActionIntent. Contains primitives only.
class_name ActionIntentSnapshot
extends RefCounted

var action_button: int = 0
var source_frame: int = 0
var direction_x: int = 0
var direction_y: int = 0
var facing_at_request: int = 1
var forward_held: bool = false
var back_held: bool = false

static func from_intent(intent: ActionIntent) -> ActionIntentSnapshot:
    if intent == null:
        return null
    var result := ActionIntentSnapshot.new()
    result.action_button = intent.action_button
    result.source_frame = intent.source_frame
    result.direction_x = intent.direction_x
    result.direction_y = intent.direction_y
    result.facing_at_request = intent.facing_at_request
    result.forward_held = intent.forward_held
    result.back_held = intent.back_held
    return result

func to_intent() -> ActionIntent:
    var result := ActionIntent.new(action_button, source_frame, direction_x, direction_y, facing_at_request)
    result.forward_held = forward_held
    result.back_held = back_held
    return result
