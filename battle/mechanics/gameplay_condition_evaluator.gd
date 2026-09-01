# Pure generic deterministic condition evaluation over simulation facts.
class_name GameplayConditionEvaluator
extends RefCounted

const FLAG_COUNTER_HIT: int = 1 << 0
const FLAG_DEFENDER_FORWARD_WALK: int = 1 << 1
const FLAG_DEFENDER_FORWARD_DASH: int = 1 << 2
const FLAG_DEFENDER_ADVANCING: int = 1 << 3
const FLAG_DEFENDER_AIRBORNE: int = 1 << 4
const FLAG_DEFENDER_GUARDING: int = 1 << 5
const FLAG_DEFENDER_CROUCH_GUARDING: int = 1 << 6
const FLAG_DEFENDER_MOVEMENT_INTENT: int = 1 << 7
const FLAG_DEFENDER_EXITING_CROUCH_GUARD: int = 1 << 8

static func contact_flags(defender: Fighter) -> int:
    if defender == null:
        return 0
    var flags := 0
    var state := defender.state_machine.state
    if state == FighterStateMachine.State.GROUND_ATTACK or state == FighterStateMachine.State.AIR_ATTACK or state == FighterStateMachine.State.CHARGE:
        flags |= FLAG_COUNTER_HIT
    if state == FighterStateMachine.State.WALK_FORWARD:
        flags |= FLAG_DEFENDER_FORWARD_WALK | FLAG_DEFENDER_ADVANCING
    if state == FighterStateMachine.State.DASH_FORWARD:
        flags |= FLAG_DEFENDER_FORWARD_DASH | FLAG_DEFENDER_ADVANCING
    if state in [FighterStateMachine.State.GROUND_ATTACK, FighterStateMachine.State.AIR_ATTACK] and defender.mechanics_runtime != null and defender.mechanics_runtime.movement_intent_x > 0:
        flags |= FLAG_DEFENDER_ADVANCING
    if defender.movement_motor.is_airborne():
        flags |= FLAG_DEFENDER_AIRBORNE
    if defender.state_machine.is_guarding():
        flags |= FLAG_DEFENDER_GUARDING
        if defender.state_machine.guard_posture == FighterStateMachine.GuardPosture.CROUCHING:
            flags |= FLAG_DEFENDER_CROUCH_GUARDING
    if defender.mechanics_runtime != null and defender.mechanics_runtime.movement_intent_x != 0:
        flags |= FLAG_DEFENDER_MOVEMENT_INTENT
    if defender.mechanics_runtime != null and defender.mechanics_runtime.exiting_crouch_guard():
        flags |= FLAG_DEFENDER_EXITING_CROUCH_GUARD
    return flags

static func matches_all(conditions: Array[GameplayConditionData], attacker: Fighter, defender: Fighter, flags: int = 0, temp_entities: TemporaryEntitySystem = null) -> bool:
    for condition: GameplayConditionData in conditions:
        if condition != null and not matches(condition, attacker, defender, flags, temp_entities):
            return false
    return true

static func matches(condition: GameplayConditionData, attacker: Fighter, defender: Fighter, flags: int = 0, temp_entities: TemporaryEntitySystem = null) -> bool:
    if condition == null:
        return true
    var raw := _matches_raw(condition, attacker, defender, flags, temp_entities)
    return not raw if condition.invert else raw

static func _matches_raw(condition: GameplayConditionData, attacker: Fighter, defender: Fighter, flags: int, temp_entities: TemporaryEntitySystem) -> bool:
    match condition.type:
        GameplayConditionData.Type.ALWAYS:
            return true
        GameplayConditionData.Type.COUNTER_HIT:
            return (flags & FLAG_COUNTER_HIT) != 0
        GameplayConditionData.Type.DEFENDER_FORWARD_WALK:
            return (flags & FLAG_DEFENDER_FORWARD_WALK) != 0
        GameplayConditionData.Type.DEFENDER_FORWARD_DASH:
            return (flags & FLAG_DEFENDER_FORWARD_DASH) != 0
        GameplayConditionData.Type.DEFENDER_ADVANCING:
            return (flags & FLAG_DEFENDER_ADVANCING) != 0
        GameplayConditionData.Type.DEFENDER_AIRBORNE:
            return (flags & FLAG_DEFENDER_AIRBORNE) != 0
        GameplayConditionData.Type.DEFENDER_HAS_STATUS:
            return defender != null and defender.statuses.has_status(condition.id)
        GameplayConditionData.Type.ATTACKER_HAS_STATUS:
            return attacker != null and attacker.statuses.has_status(condition.id)
        GameplayConditionData.Type.ATTACKER_MODE:
            return attacker != null and attacker.mode.active_mode_id == condition.id
        GameplayConditionData.Type.RESOURCE_AT_LEAST:
            return attacker != null and attacker.resources.get_value(condition.id) >= condition.value
        GameplayConditionData.Type.BACKWARD_JUMP_ATTACK:
            return attacker != null and attacker.mechanics_runtime.backward_jump_attack()
        GameplayConditionData.Type.LATE_DESCENDING_AIR_ATTACK:
            return attacker != null and attacker.mechanics_runtime.late_descending_air_attack(attacker.movement_motor)
        GameplayConditionData.Type.TARGET_INSIDE_OWNER_AREA:
            return temp_entities != null and attacker != null and defender != null and temp_entities.target_inside_owner_area(attacker.fighter_id, defender.movement_motor.sim_position, condition.group_id)
        GameplayConditionData.Type.DEFENDER_GUARDING:
            return (flags & FLAG_DEFENDER_GUARDING) != 0
        GameplayConditionData.Type.DEFENDER_CROUCH_GUARDING:
            return (flags & FLAG_DEFENDER_CROUCH_GUARDING) != 0
        GameplayConditionData.Type.DEFENDER_MOVEMENT_INTENT:
            return (flags & FLAG_DEFENDER_MOVEMENT_INTENT) != 0
        GameplayConditionData.Type.DEFENDER_EXITING_CROUCH_GUARD:
            return (flags & FLAG_DEFENDER_EXITING_CROUCH_GUARD) != 0
        GameplayConditionData.Type.TARGET_GROUNDED:
            return defender != null and not defender.movement_motor.is_airborne()
        GameplayConditionData.Type.TARGET_GRABBABLE:
            return defender != null and defender.state_machine.is_throwable()
        GameplayConditionData.Type.TARGET_NOT_IN_ORDINARY_HITSTUN:
            return defender != null and defender.combatant.hitstun_remaining <= 0
        GameplayConditionData.Type.RESOURCE_AT_MOVE_START_AT_LEAST:
            return attacker != null and attacker.move_runner.activation_resource_value(condition.id) >= condition.value
    return false
