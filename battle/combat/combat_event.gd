# Responsibility: One-way simulation -> observer event payload.
# Owns: deterministic observation facts and stable provenance IDs.
# Does NOT own: combat mutation, animation playback, VFX/audio implementation, presentation dedupe state.
# Dependencies: HitResult/round enum scalar facts only; no gameplay Resources.
class_name CombatEvent
extends RefCounted

enum EventType {
    MOVE_STARTED,
    HIT,
    BLOCK,
    THROW,
    THROW_TECH,
    KO,
    STATE_CHANGED,
    ROUND_STARTED,
    ROUND_ENDED,
    TIME_UP,
    MATCH_ENDED,
}

var type: EventType = EventType.HIT
var frame_number: int = 0
var attacker_id: int = 0
var defender_id: int = 0
var move_id: StringName = &""
var attack_instance_id: int = 0
var hit_id: int = 0
var projectile_instance_id: int = 0
var source_runtime_id: int = 0
var attack_source_kind: int = HitResult.AttackSourceKind.FIGHTER_BODY
var projectile_id: StringName = &""
var raw_damage: int = 0
var scaled_damage: int = 0
var damage_scale_percent: int = 100
var position: Vector2 = Vector2.ZERO
var value_before: int = 0
var value_after: int = 0
var hitstop_frames: int = 0
var hit_level: int = MoveData.HitLevel.MID
var state_name: StringName = &""
var result_type: int = -1
var counter_hit: bool = false
var defender_airborne: bool = false
var defender_move_phase: StringName = &"NONE"
var distance_units: int = 0
var attacker_cornered: bool = false
var defender_cornered: bool = false
var round_number: int = 0
var round_result: int = 0
var timeout: bool = false

static func move_started(frame: int, fighter_id: int, move: StringName, instance_id: int = 0) -> CombatEvent:
    var event := CombatEvent.new()
    event.type = EventType.MOVE_STARTED
    event.frame_number = frame
    event.attacker_id = fighter_id
    event.move_id = move
    event.attack_instance_id = instance_id
    return event

static func hit(frame: int, result: HitResult, hp_before: int, hp_after: int) -> CombatEvent:
    return _strike_event(EventType.HIT, frame, result, hp_before, hp_after)

static func block(frame: int, result: HitResult, hp_before: int, hp_after: int) -> CombatEvent:
    var event := _strike_event(EventType.BLOCK, frame, result, hp_before, hp_after)
    event.type = EventType.BLOCK
    return event

static func throw_event(frame: int, result: HitResult, hp_before: int, hp_after: int) -> CombatEvent:
    return _strike_event(EventType.THROW, frame, result, hp_before, hp_after)

static func throw_tech(frame: int, attacker_id_value: int, defender_id_value: int, move: StringName, instance_id: int) -> CombatEvent:
    var event := CombatEvent.new()
    event.type = EventType.THROW_TECH
    event.frame_number = frame
    event.attacker_id = attacker_id_value
    event.defender_id = defender_id_value
    event.move_id = move
    event.attack_instance_id = instance_id
    return event

static func ko(frame: int, result: HitResult, hp_before: int = -1, hp_after: int = -1) -> CombatEvent:
    var event := CombatEvent.new()
    event.type = EventType.KO
    event.frame_number = frame
    if result != null:
        _copy_result_provenance(event, result)
        event.position = result.hit_position
        event.result_type = result.result_type
        event.raw_damage = result.raw_damage
        event.damage_scale_percent = result.damage_scale_percent
    if result != null:
        # Scaled damage is the authoritative post-proration result before HP clamping/overkill.
        event.scaled_damage = maxi(0, result.damage)
    if hp_before >= 0 and hp_after >= 0:
        event.value_before = hp_before
        event.value_after = hp_after
    return event

static func round_started(frame: int, round_value: int) -> CombatEvent:
    var event := CombatEvent.new()
    event.type = EventType.ROUND_STARTED
    event.frame_number = frame
    event.round_number = round_value
    return event

static func round_ended(frame: int, round_value: int, result_value: int, was_timeout: bool) -> CombatEvent:
    var event := CombatEvent.new()
    event.type = EventType.ROUND_ENDED
    event.frame_number = frame
    event.round_number = round_value
    event.round_result = result_value
    event.timeout = was_timeout
    return event

static func time_up(frame: int, round_value: int, result_value: int) -> CombatEvent:
    var event := CombatEvent.round_ended(frame, round_value, result_value, true)
    event.type = EventType.TIME_UP
    return event

static func match_ended(frame: int, winner: int, round_value: int) -> CombatEvent:
    var event := CombatEvent.new()
    event.type = EventType.MATCH_ENDED
    event.frame_number = frame
    event.attacker_id = winner
    event.round_number = round_value
    return event

static func _strike_event(event_type: EventType, frame: int, result: HitResult, hp_before: int, hp_after: int) -> CombatEvent:
    var event := CombatEvent.new()
    event.type = event_type
    event.frame_number = frame
    _copy_result_provenance(event, result)
    event.position = result.hit_position
    event.value_before = hp_before
    event.value_after = hp_after
    event.raw_damage = result.raw_damage
    # Preserve post-proration damage separately from actual HP lost to overkill/clamping.
    event.scaled_damage = maxi(0, result.damage)
    event.damage_scale_percent = result.damage_scale_percent
    event.hitstop_frames = result.hitstop_defender
    event.hit_level = result.hit_level
    event.result_type = result.result_type
    return event

static func _copy_result_provenance(event: CombatEvent, result: HitResult) -> void:
    event.attacker_id = result.attacker_id
    event.defender_id = result.defender_id
    event.move_id = result.move_id
    event.attack_instance_id = result.attack_instance_id
    event.hit_id = result.hit_id
    event.counter_hit = result.counter_hit
    event.defender_airborne = result.defender_airborne
    event.defender_move_phase = result.defender_move_phase
    event.distance_units = result.distance_units
    event.attacker_cornered = result.attacker_cornered
    event.defender_cornered = result.defender_cornered
    event.hit_level = result.hit_level
    event.attack_source_kind = result.attack_source_kind
    event.source_runtime_id = result.source_runtime_id
    event.projectile_id = result.projectile_id
    if result.attack_source_kind == HitResult.AttackSourceKind.PROJECTILE:
        event.projectile_instance_id = result.source_runtime_id
