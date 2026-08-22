# Responsibility: A-DATA-003/004/005 match, move and mastery aggregation tests.
class_name MatchTelemetryAggregatorTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_move_summary_and_mastery_records()
    _test_match_summary_contract_and_deduplication()
    print("\nA-DATA match/move/mastery tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle() -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(load("res://data/characters/generic_fighter.tres"), load("res://data/characters/zone_fighter.tres"))
    return battle

func _result(move_id: StringName, instance_id: int, damage: int = 40) -> HitResult:
    var result := HitResult.new()
    result.attacker_id = 1
    result.defender_id = 2
    result.move_id = move_id
    result.attack_instance_id = instance_id
    result.hit_id = 1
    result.damage = damage
    result.hit_position = Vector2(60, 50)
    result.distance_units = 18000
    result.defender_cornered = true
    return result

func _record_names(records: Array[Dictionary]) -> Array[String]:
    var names: Array[String] = []
    for record in records:
        names.append(str(record.get("event_name", "")))
    return names

func _find_record(records: Array[Dictionary], event_name: String, move_id: String = "") -> Dictionary:
    for record in records:
        if record.get("event_name", "") != event_name:
            continue
        var payload: Dictionary = record.get("payload", {})
        if move_id.is_empty() or payload.get("move_id", "") == move_id:
            return record
    return {}

func _test_move_summary_and_mastery_records() -> void:
    var battle := _battle()
    var aggregator := TelemetryMatchAggregator.new()
    aggregator.begin_match("generic_fighter", "zone_fighter", "local_2p", "replay-test", 0)

    var hit_result := _result(&"stand_light", 1000001, 50)
    hit_result.counter_hit = true
    hit_result.defender_airborne = true
    hit_result.defender_move_phase = &"RECOVERY"
    var hit := CombatEvent.hit(10, hit_result, 1000, 950)
    var block := CombatEvent.block(11, _result(&"stand_light", 1000001, 0), 950, 950)
    var throw_event := CombatEvent.throw_event(12, _result(&"ground_throw", 1000003, 80), 950, 870)
    var second_hit := CombatEvent.hit(13, _result(&"stand_light", 1000001, 30), 870, 840)
    var ultimate_result := _result(MoveIds.ULTIMATE, 1000004, 300)
    var ko := CombatEvent.ko(20, ultimate_result)
    var events: Array[CombatEvent] = [
        CombatEvent.move_started(1, 1, &"stand_light", 1000001),
        hit,
        block,
        second_hit,
        CombatEvent.move_started(14, 1, &"stand_heavy", 1000002),
        CombatEvent.move_started(15, 1, &"ground_throw", 1000003),
        throw_event,
        CombatEvent.move_started(16, 1, MoveIds.ULTIMATE, 1000004),
        ko,
    ]
    var immediate := aggregator.observe(events, battle)
    var names := _record_names(immediate)
    for expected in ["mastery.anti_air_success", "mastery.whiff_punish_success", "mastery.guard_success", "mastery.throw_success", "mastery.ultimate_finish"]:
        t.that(names.has(expected), "Resolved facts emit %s" % expected)

    var completed := aggregator.complete(battle, "completed", {"replay_id": "replay-test", "replay_path": "user://replays/replay-test.tbf_replay.json", "replay_saved": true})
    var all_records := immediate.duplicate()
    all_records.append_array(completed)
    t.that(_record_names(all_records).has("mastery.combo_completion"), "Two linked hits emit combo completion")
    var light := _find_record(completed, "move.summary", "stand_light")
    var light_payload: Dictionary = light.get("payload", {})
    t.equal(light_payload.get("use_count", 0), 1, "Move summary counts uses")
    t.equal(light_payload.get("hit_count", 0), 2, "Move summary counts multi-hit results")
    t.equal(light_payload.get("block_count", 0), 1, "Move summary counts blocks")
    t.equal(light_payload.get("punish_count", 0), 1, "Move summary counts recovery punishes")
    t.equal(light_payload.get("counter_hit_count", 0), 1, "Move summary counts counter hits")
    t.equal(light_payload.get("damage", 0), 80, "Move summary totals authoritative HP damage")
    t.equal(light_payload.get("distance_buckets", {}).get("mid", 0), 3, "Move summary buckets resolved distance")
    t.equal(light_payload.get("corner_states", {}).get("defender_cornered", 0), 3, "Move summary buckets corner state")
    var whiff := _find_record(completed, "move.summary", "stand_heavy")
    t.equal(whiff.get("payload", {}).get("whiff_count", 0), 1, "Unresolved move instance becomes one whiff")

func _test_match_summary_contract_and_deduplication() -> void:
    var battle := _battle()
    var aggregator := TelemetryMatchAggregator.new()
    aggregator.begin_match("generic_fighter", "zone_fighter", "vs_cpu", "replay-test", 0)
    var move := CombatEvent.move_started(1, 1, &"stand_light", 1000001)
    aggregator.observe([move, move], battle)
    battle.frame_number = 180
    var completed := aggregator.complete(battle, "reset", {"replay_id": "replay-test", "replay_path": "user://replays/replay-test.tbf_replay.json", "replay_saved": false})
    var move_summary := _find_record(completed, "move.summary", "stand_light")
    t.equal(move_summary.get("payload", {}).get("use_count", 0), 1, "Duplicate combat events are ignored")
    var summary := _find_record(completed, "match.completed")
    var payload: Dictionary = summary.get("payload", {})
    for key in ["fighter_ids", "winner", "round_count", "match_duration_frames", "match_duration_ms", "mode", "build_id", "content_version", "disconnect_reason", "replay_id", "replay_path", "replay_saved"]:
        t.that(payload.has(key), "Match summary contains %s" % key)
    t.equal(payload.get("mode", ""), "vs_cpu", "Match summary preserves CPU/local mode vocabulary")
    t.equal(payload.get("disconnect_reason", ""), "reset", "Interrupted match records disconnect reason")
    t.equal(aggregator.complete(battle, "reset", {}).size(), 0, "Match completion is one-shot")
