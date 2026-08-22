# Responsibility: Stable contextual ActionIntent -> Move ID mapping for ground and air actions.
# Owns: Ground normal/throw/Special/Ultimate and air-attack selection using request-frame intent context.
# Does NOT own: Jump, Dash, Backstep, input buffering, state legality, MoveData lookup, move execution.
# Dependencies: ActionIntent, InputFrame, MoveIds.
class_name ActionMoveMap
extends RefCounted

static func ground_move_id_for_intent(intent: ActionIntent) -> StringName:
    if intent == null:
        return &""
    match intent.action_button:
        InputFrame.InputButton.LIGHT:
            if intent.direction_y < 0:
                return MoveIds.CROUCH_LOW
            return MoveIds.STAND_LIGHT
        InputFrame.InputButton.HEAVY:
            if intent.forward_held:
                return MoveIds.GROUND_THROW
            return MoveIds.STAND_HEAVY
        InputFrame.InputButton.SPECIAL:
            return MoveIds.SPECIAL_NEUTRAL
        InputFrame.InputButton.ULTIMATE:
            return MoveIds.ULTIMATE
        _:
            return &""

static func air_move_id_for_intent(intent: ActionIntent) -> StringName:
    if intent == null:
        return &""
    if intent.action_button == InputFrame.InputButton.LIGHT or intent.action_button == InputFrame.InputButton.HEAVY:
        return MoveIds.AIR_ATTACK
    return &""
