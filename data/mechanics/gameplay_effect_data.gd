# Generic deterministic gameplay effect descriptor. Presentation never executes these.
class_name GameplayEffectData
extends Resource

enum Target { ATTACKER, DEFENDER }

enum Type {
    APPLY_STATUS,
    REMOVE_STATUS,
    EXTEND_STATUS_ONCE,
    GAIN_RESOURCE,
    SPEND_RESOURCE,
    SET_RESOURCE,
    ENTER_MODE,
    EXIT_MODE,
    SELF_DAMAGE_NONLETHAL,
    ADD_SELF_VELOCITY,
    POSITION_EFFECT,
    SPAWN_AREA,
    SPAWN_SUMMON,
    SPAWN_HAZARD,
    START_SEQUENCE,
    FORCE_TRIGGER_AREA,
    GRANT_PANIC_EXIT,
    ADD_RESOLVE,
    APPLY_ARMOR_CHARGE,
    CLEAR_ARMOR,
    MODIFY_KNOCKDOWN,
    FORCE_STAND,
    CONSUME_STATUS,
    SET_PRESENTATION_EVENT_TAG,
}

@export var type: Type = Type.SET_PRESENTATION_EVENT_TAG
@export var target: Target = Target.DEFENDER
@export var conditions: Array[GameplayConditionData] = []
@export var id: StringName = &""
@export var value: int = 0
@export var value_b: int = 0
@export var vector_units: Vector2i = Vector2i.ZERO
@export var status: StatusEffectData
@export var mode: ModeData
@export var positioning: PositioningEffectData
@export var area: AreaData
@export var summon: SummonData
@export var hazard: HazardData
@export var sequence: SequenceData
