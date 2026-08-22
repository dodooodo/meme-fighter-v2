# Responsibility: Interpret normalized InputFrame + InputHistory into device-independent gameplay queries.
# Owns: current direction/action parse results, direction edges, relative double-tap command flags, contextual ActionIntent.
# Does NOT own: history storage, device polling, state transitions, buffering, move execution.
# Dependencies: InputFrame, InputHistory, DirectionCommandRecognizer, ActionIntent.
class_name InputParser
extends RefCounted

var move_axis_x: int = 0
var world_left_held: bool = false
var world_right_held: bool = false
var up_held: bool = false
var up_pressed: bool = false
var down_held: bool = false
var forward_held: bool = false
var back_held: bool = false
var dash_forward_pressed: bool = false
var backstep_pressed: bool = false

var light_pressed: bool = false
var light_held: bool = false
var light_released: bool = false
var heavy_pressed: bool = false
var heavy_held: bool = false
var heavy_released: bool = false
var guard_pressed: bool = false
var guard_held: bool = false
var guard_released: bool = false
var special_pressed: bool = false
var special_held: bool = false
var special_released: bool = false
var ultimate_pressed: bool = false
var ultimate_held: bool = false
var ultimate_released: bool = false

var _source_frame: int = 0
var _direction_y: int = 0
var _facing_at_parse: int = 1

func update(frame: InputFrame, facing: int, history: InputHistory = null) -> void:
    _source_frame = frame.frame_number
    move_axis_x = frame.direction_x
    _direction_y = frame.direction_y
    _facing_at_parse = -1 if facing < 0 else 1

    world_left_held = frame.direction_x < 0
    world_right_held = frame.direction_x > 0
    down_held = frame.direction_y < 0
    up_held = frame.direction_y > 0
    forward_held = move_axis_x != 0 and move_axis_x == _facing_at_parse
    back_held = move_axis_x != 0 and move_axis_x == -_facing_at_parse

    var previous_frame: InputFrame = history.get_recent(1) if history != null else null
    up_pressed = up_held and (previous_frame == null or previous_frame.direction_y <= 0)
    # Formal gameplay path requires InputHistory. Standalone parser calls remain edge-safe but do not recognize double taps.
    dash_forward_pressed = DirectionCommandRecognizer.recognize_forward_dash(history, _facing_at_parse) if history != null else false
    backstep_pressed = DirectionCommandRecognizer.recognize_backstep(history, _facing_at_parse) if history != null else false

    light_pressed = frame.is_pressed(InputFrame.InputButton.LIGHT)
    light_held = frame.is_held(InputFrame.InputButton.LIGHT)
    light_released = frame.is_released(InputFrame.InputButton.LIGHT)
    heavy_pressed = frame.is_pressed(InputFrame.InputButton.HEAVY)
    heavy_held = frame.is_held(InputFrame.InputButton.HEAVY)
    heavy_released = frame.is_released(InputFrame.InputButton.HEAVY)
    guard_pressed = frame.is_pressed(InputFrame.InputButton.GUARD)
    guard_held = frame.is_held(InputFrame.InputButton.GUARD)
    guard_released = frame.is_released(InputFrame.InputButton.GUARD)
    special_pressed = frame.is_pressed(InputFrame.InputButton.SPECIAL)
    special_held = frame.is_held(InputFrame.InputButton.SPECIAL)
    special_released = frame.is_released(InputFrame.InputButton.SPECIAL)
    ultimate_pressed = frame.is_pressed(InputFrame.InputButton.ULTIMATE)
    ultimate_held = frame.is_held(InputFrame.InputButton.ULTIMATE)
    ultimate_released = frame.is_released(InputFrame.InputButton.ULTIMATE)

func action_pressed_intent() -> ActionIntent:
    # Deterministic same-frame priority: ULTIMATE > SPECIAL > HEAVY (including Throw mapping) > LIGHT.
    var action_button := 0
    if ultimate_pressed:
        action_button = InputFrame.InputButton.ULTIMATE
    elif special_pressed:
        action_button = InputFrame.InputButton.SPECIAL
    elif heavy_pressed:
        action_button = InputFrame.InputButton.HEAVY
    elif light_pressed:
        action_button = InputFrame.InputButton.LIGHT
    else:
        return null
    return ActionIntent.new(action_button, _source_frame, move_axis_x, _direction_y, _facing_at_parse)

func normal_attack_pressed_intent() -> ActionIntent:
    # Compatibility API retained for M2 tests/callers; intentionally ignores Special/Ultimate.
    var action_button := 0
    if heavy_pressed:
        action_button = InputFrame.InputButton.HEAVY
    elif light_pressed:
        action_button = InputFrame.InputButton.LIGHT
    else:
        return null
    return ActionIntent.new(action_button, _source_frame, move_axis_x, _direction_y, _facing_at_parse)
