class_name PositioningEffectData
extends Resource

enum Type {
    NONE,
    PUSH_DEFENDER,
    PUSH_ATTACKER,
    SET_TARGET_SEPARATION,
    SIDE_SWITCH,
    KEEP_CLOSE,
    RESET_TO_MID_RANGE,
    PUSH_BOTH_APART,
    CORNER_SAFE_RESET,
    # Outward-only spacing: increases separation up to distance_units but never pulls.
    PUSH_TO_MINIMUM_SEPARATION,
}

@export var type: Type = Type.NONE
@export var distance_units: int = 0
@export var attacker_distance_units: int = 0
