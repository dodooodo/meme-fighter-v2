# Responsibility: Compatibility facade for legacy ground normal-action callers.
# Owns: Delegation from legacy move_id_for_intent() to ActionMoveMap ground routing.
# Does NOT own: Gameplay mapping policy, state legality, buffering, MoveData lookup, move execution.
# Dependencies: ActionIntent, ActionMoveMap.
class_name NormalAttackMoveMap
extends RefCounted

static func move_id_for_intent(intent: ActionIntent) -> StringName:
    return ActionMoveMap.ground_move_id_for_intent(intent)
