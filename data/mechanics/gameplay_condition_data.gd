# Generic deterministic condition descriptor used by roster mechanics.
class_name GameplayConditionData
extends Resource

enum Type {
    ALWAYS,
    COUNTER_HIT,
    DEFENDER_FORWARD_WALK,
    DEFENDER_FORWARD_DASH,
    DEFENDER_ADVANCING,
    DEFENDER_AIRBORNE,
    DEFENDER_HAS_STATUS,
    ATTACKER_HAS_STATUS,
    ATTACKER_MODE,
    RESOURCE_AT_LEAST,
    BACKWARD_JUMP_ATTACK,
    LATE_DESCENDING_AIR_ATTACK,
    TARGET_INSIDE_OWNER_AREA,
    DEFENDER_GUARDING,
    DEFENDER_CROUCH_GUARDING,
    DEFENDER_MOVEMENT_INTENT,
    DEFENDER_EXITING_CROUCH_GUARD,
    TARGET_GROUNDED,
    TARGET_GRABBABLE,
    TARGET_NOT_IN_ORDINARY_HITSTUN,
    RESOURCE_AT_MOVE_START_AT_LEAST,
}

@export var type: Type = Type.ALWAYS
@export var id: StringName = &""
@export var value: int = 0
@export var group_id: StringName = &""

@export var invert: bool = false
