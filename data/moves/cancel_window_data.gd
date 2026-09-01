# Responsibility: Typed data definition for one move cancel window.
# Owns: inclusive frame range, connection condition, stable allowed target move IDs.
# Does NOT own: input buffering, MoveRunner progression, meter spending, collision, state mutation.
# Dependencies: stable StringName move IDs only.
class_name CancelWindowData
extends Resource

enum TargetKind { MOVE, MOVEMENT_ACTION_DASH_FORWARD }

enum Condition {
    ALWAYS,
    ON_HIT,
    ON_BLOCK,
    ON_HIT_OR_BLOCK,
}

@export_range(1, 600, 1) var start_frame: int = 1
@export_range(1, 600, 1) var end_frame: int = 1
@export var condition: Condition = Condition.ALWAYS
@export var allowed_target_move_ids: Array[StringName] = []
@export var target_kind: TargetKind = TargetKind.MOVE
@export var movement_resource_cost_id: StringName = &""
@export var movement_resource_cost_amount: int = 0
# 0 = unlimited. Used by finite-resource mode cancels such as True Face; runtime accounting stays generic.
@export_range(0, 20, 1) var max_uses_per_combo: int = 0
@export var resource_condition_id: StringName = &""
@export var resource_at_least: int = 0

func contains_frame(frame: int) -> bool:
    return frame >= start_frame and frame <= end_frame

func allows_target(move_id: StringName) -> bool:
    return allowed_target_move_ids.has(move_id)

func condition_met(connected_hit: bool, connected_block: bool) -> bool:
    match condition:
        Condition.ALWAYS:
            return true
        Condition.ON_HIT:
            return connected_hit
        Condition.ON_BLOCK:
            return connected_block
        Condition.ON_HIT_OR_BLOCK:
            return connected_hit or connected_block
    return false

func resource_condition_met(resources: FighterResourceComponent) -> bool:
    if resource_condition_id == &"":
        return true
    return resources != null and resources.get_value(resource_condition_id) >= resource_at_least

func allows_dash_forward() -> bool:
    return target_kind == TargetKind.MOVEMENT_ACTION_DASH_FORWARD
