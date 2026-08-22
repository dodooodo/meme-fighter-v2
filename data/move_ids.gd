# Responsibility: Central identifiers for framework-recognized MoveData requests.
# Owns: stable StringName constants only.
# Does NOT own: MoveData, move lookup, runtime move state, character-specific branching.
# Dependencies: none.
class_name MoveIds
extends RefCounted

const STAND_LIGHT: StringName = &"stand_light"
const STAND_HEAVY: StringName = &"stand_heavy"
const CROUCH_LOW: StringName = &"crouch_low"
const AIR_ATTACK: StringName = &"air_attack"
const GROUND_THROW: StringName = &"ground_throw"

const SPECIAL_NEUTRAL: StringName = &"special_neutral"
const SPECIAL_NEUTRAL_L2: StringName = &"special_neutral_l2"
const SPECIAL_NEUTRAL_L3: StringName = &"special_neutral_l3"
const ULTIMATE: StringName = &"ultimate"
