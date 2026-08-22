# M7 deterministic event identity and dedupe ledger tests.
class_name PresentationEventIdentityTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_hit_identity_fields()
    _test_projectile_and_round_identity()
    _test_ledger_dedupe_and_reset()
    print("\nM7 PresentationEvent identity tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _hit_event(frame: int, instance_id: int, projectile_id: int = 0) -> CombatEvent:
    var result := HitResult.new()
    result.attacker_id = 1
    result.defender_id = 2
    result.move_id = &"stand_light"
    result.attack_instance_id = instance_id
    result.source_runtime_id = projectile_id
    result.attack_source_kind = HitResult.AttackSourceKind.PROJECTILE if projectile_id > 0 else HitResult.AttackSourceKind.FIGHTER_BODY
    result.hit_position = Vector2(600, 400)
    return CombatEvent.hit(frame, result, 1000, 950)

func _test_hit_identity_fields() -> void:
    var a := _hit_event(120, 17)
    var b := _hit_event(120, 17)
    t.equal(PresentationEventId.canonical(a), PresentationEventId.canonical(b), "Same deterministic HIT facts produce same PresentationEvent ID")
    t.that(PresentationEventId.canonical(_hit_event(121, 17)) != PresentationEventId.canonical(a), "Different simulation frame changes event ID")
    t.that(PresentationEventId.canonical(_hit_event(120, 18)) != PresentationEventId.canonical(a), "Different AttackInstanceID changes event ID")
    var other_participant := _hit_event(120, 17)
    other_participant.defender_id = 1
    t.that(PresentationEventId.canonical(other_participant) != PresentationEventId.canonical(a), "Different participant changes event ID")

func _test_projectile_and_round_identity() -> void:
    var p1 := _hit_event(200, 9, 9)
    var p2 := _hit_event(200, 10, 10)
    t.that(PresentationEventId.canonical(p1) != PresentationEventId.canonical(p2), "Different ProjectileInstanceID changes event ID")
    var r1 := CombatEvent.round_started(500, 1)
    var r2 := CombatEvent.round_started(500, 2)
    t.that(PresentationEventId.canonical(r1) != PresentationEventId.canonical(r2), "ROUND_STARTED round 1 and round 2 have distinct IDs")

func _test_ledger_dedupe_and_reset() -> void:
    var ledger := PresentationEventLedger.new()
    var event := _hit_event(120, 17)
    t.that(ledger.consume_once(event), "Ledger accepts first presentation event")
    t.that(not ledger.consume_once(event), "Ledger rejects exact duplicate event ID")
    t.equal(ledger.count(), 1, "Ledger retains one event after duplicate")
    t.that(ledger.consume_once(_hit_event(121, 17)), "Ledger accepts a different deterministic event ID")
    ledger.clear()
    t.equal(ledger.count(), 0, "Full presentation reset clears ledger")
    t.that(ledger.consume_once(event), "Cleared ledger accepts original event again")
