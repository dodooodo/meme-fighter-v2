# Gate 3 telemetry contract tests. Telemetry observes resolved facts and never changes authoritative hash/replay truth.
class_name Gate3TelemetryTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_resolved_event_provenance()
    _test_state_diff_events()
    _test_projectile_summon_and_trap_events()
    _test_non_authority_hash_equivalence()
    _test_sink_failure_isolated()
    print("\nGate 3 Telemetry tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a_id: StringName = &"pink_star", b_id: StringName = &"sauce_stubble_dog") -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(RosterRegistry.character_by_id(a_id), RosterRegistry.character_by_id(b_id), null, null, Vector2i(36000, BattleSimulation.GROUND_Y_UNITS), Vector2i(72000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _result(result_type: int, instance_id: int, move_id: StringName = MoveIds.STAND_LIGHT) -> HitResult:
    var result := HitResult.new()
    result.result_type = result_type
    result.attacker_id = 1
    result.defender_id = 2
    result.move_id = move_id
    result.attack_instance_id = instance_id
    result.hit_id = 0
    result.raw_damage = 50
    result.damage = 40
    result.damage_scale_percent = 80
    result.hit_level = MoveData.HitLevel.MID
    result.distance_units = 18000
    return result

func _names(records: Array[Dictionary]) -> Array[String]:
    var out: Array[String] = []
    for record: Dictionary in records:
        out.append(str(record.get("event_name", "")))
    return out

func _payload_for(records: Array[Dictionary], event_name: String) -> Dictionary:
    for record: Dictionary in records:
        if str(record.get("event_name", "")) == event_name:
            return record.get("payload", {})
    return {}

func _test_resolved_event_provenance() -> void:
    var battle := _battle()
    var aggregator := TelemetryMatchAggregator.new()
    t.that(aggregator.begin_match("pink_star", "sauce_stubble_dog", "local_2p", "gate3-events"), "Telemetry aggregator begins match")
    aggregator.observe([], battle)
    var hit_result := _result(HitResult.ResultType.HIT, 101)
    hit_result.counter_hit = true
    hit_result.defender_move_phase = &"RECOVERY"
    var hit_event := CombatEvent.hit(10, hit_result, 950, 920)
    var records := aggregator.observe([CombatEvent.move_started(9, 1, MoveIds.STAND_LIGHT, 101), hit_event], battle)
    var names := _names(records)
    for expected in ["combat.move_start", "combat.hit", "combat.counter_hit", "combat.punish"]:
        t.that(expected in names, "Telemetry emits representative event: %s" % expected)
    var hit_payload := _payload_for(records, "combat.hit")
    t.equal(int(hit_payload.get("raw_damage", -1)), 50, "Telemetry reads authoritative raw damage")
    t.equal(int(hit_payload.get("scaled_damage", -1)), 40, "Telemetry preserves post-scaling damage separate from HP clamp")
    t.equal(int(hit_payload.get("actual_hp_damage", -1)), 30, "Telemetry derives actual HP damage from resolved before/after facts")
    t.equal(int(hit_payload.get("hp_before", -1)), 950, "Hit telemetry carries HP before")
    t.equal(int(hit_payload.get("hp_after", -1)), 920, "Hit telemetry carries HP after")

    var block_result := _result(HitResult.ResultType.BLOCK, 102, MoveIds.STAND_HEAVY)
    block_result.damage = 0
    var block_records := aggregator.observe([CombatEvent.move_started(19, 1, MoveIds.STAND_HEAVY, 102), CombatEvent.block(20, block_result, 920, 920)], battle)
    t.that("combat.block" in _names(block_records), "Telemetry emits block")

    var throw_result := _result(HitResult.ResultType.THROW, 103, MoveIds.GROUND_THROW)
    var throw_records := aggregator.observe([CombatEvent.move_started(29, 1, MoveIds.GROUND_THROW, 103), CombatEvent.throw_event(30, throw_result, 920, 880)], battle)
    t.that("combat.throw_attempt" in _names(throw_records), "Telemetry emits throw attempt from generic throw MoveData")
    t.that("combat.throw_success" in _names(throw_records), "Telemetry emits throw success")
    var tech_records := aggregator.observe([CombatEvent.throw_tech(40, 1, 2, MoveIds.GROUND_THROW, 104)], battle)
    t.that("combat.throw_tech" in _names(tech_records), "Telemetry emits throw tech")

    var ko_result := _result(HitResult.ResultType.HIT, 105, MoveIds.STAND_HEAVY)
    ko_result.raw_damage = 120
    ko_result.damage = 96
    var ko_records := aggregator.observe([CombatEvent.ko(50, ko_result, 60, 0)], battle)
    var ko_payload := _payload_for(ko_records, "combat.ko")
    t.equal(int(ko_payload.get("scaled_damage", -1)), 96, "KO telemetry keeps scaled move damage")
    t.equal(int(ko_payload.get("actual_hp_damage", -1)), 60, "KO telemetry separately reports actual lethal HP loss")

func _test_state_diff_events() -> void:
    var battle := _battle()
    var aggregator := TelemetryMatchAggregator.new()
    aggregator.begin_match("pink_star", "sauce_stubble_dog", "local_2p", "gate3-state-diff")
    aggregator.observe([], battle)
    battle.fighter_a.meter.set_value(25)
    battle.fighter_a.resources.set_value(&"face_actions", 3)
    battle.fighter_a.mode.enter(&"true_face", -1, battle.frame_number)
    var records := aggregator.observe([], battle)
    var names := _names(records)
    t.that("combat.meter_gain" in names, "State-diff telemetry observes meter gain")
    t.that("combat.resource_change" in names, "State-diff telemetry observes generic resource changes")
    t.that("combat.mode_enter" in names, "State-diff telemetry observes generic mode entry")

    var sauce_battle := _battle(&"sauce_stubble_dog", &"pink_star")
    var sauce_aggregator := TelemetryMatchAggregator.new()
    sauce_aggregator.begin_match("sauce_stubble_dog", "pink_star", "local_2p", "gate3-status-diff")
    sauce_aggregator.observe([], sauce_battle)
    t.that(sauce_battle.fighter_a.statuses.apply_defined(&"sauce"), "Telemetry test establishes authored Sticky status")
    records = sauce_aggregator.observe([], sauce_battle)
    t.that("combat.status_apply" in _names(records), "State-diff telemetry observes status apply")
    sauce_battle.fighter_a.statuses.extend_once(&"sauce", 90)
    records = sauce_aggregator.observe([], sauce_battle)
    t.that("combat.status_extend" in _names(records), "State-diff telemetry observes extend-once character mechanic generically")
    sauce_battle.fighter_a.statuses.remove_status(&"sauce")
    records = sauce_aggregator.observe([], sauce_battle)
    t.that("combat.status_remove" in _names(records), "State-diff telemetry observes status removal")

func _test_projectile_summon_and_trap_events() -> void:
    var battle := _battle()
    var aggregator := TelemetryMatchAggregator.new()
    aggregator.begin_match("pink_star", "sauce_stubble_dog", "local_2p", "gate3-entities")
    aggregator.observe([], battle)

    var summon := SummonData.new()
    summon.id = &"gate3_test_summon"
    summon.spawn_count = 1
    summon.max_hp = 50
    summon.lifetime_frames = 120
    var summon_ids := battle.temporary_entity_system.spawn_summon(battle.fighter_a, summon)
    var records := aggregator.observe([], battle)
    t.that("combat.summon_spawn" in _names(records), "Telemetry observes summon spawn")
    var summon_hit := _result(HitResult.ResultType.HIT, 201)
    summon_hit.attack_source_kind = HitResult.AttackSourceKind.TEMPORARY_ENTITY
    summon_hit.source_runtime_id = int(summon_ids[0])
    records = aggregator.observe([CombatEvent.hit(60, summon_hit, 900, 890)], battle)
    t.that("combat.summon_hit" in _names(records), "Telemetry classifies temporary-entity summon hit generically")

    var area := AreaData.new()
    area.id = &"gate3_test_trap"
    area.lifetime_frames = 120
    var area_ids := battle.temporary_entity_system.spawn_area(battle.fighter_a, area)
    records = aggregator.observe([], battle)
    t.that("combat.trap_spawn" in _names(records), "Telemetry observes trap/area spawn")
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.instance_id == int(area_ids[0]):
            runtime.triggered = true
    records = aggregator.observe([], battle)
    t.that("combat.trap_trigger" in _names(records), "Telemetry observes trap trigger from authoritative Area state diff")

    var projectile_hit := _result(HitResult.ResultType.HIT, 202)
    projectile_hit.attack_source_kind = HitResult.AttackSourceKind.PROJECTILE
    projectile_hit.source_runtime_id = 9001
    projectile_hit.projectile_id = &"gate3_projectile"
    records = aggregator.observe([CombatEvent.hit(70, projectile_hit, 890, 880)], battle)
    t.that("combat.projectile_hit" in _names(records), "Telemetry emits projectile hit from resolved provenance")

func _test_non_authority_hash_equivalence() -> void:
    var observed := _battle(&"alien_meow", &"doge")
    var control := _battle(&"alien_meow", &"doge")
    var aggregator := TelemetryMatchAggregator.new()
    aggregator.begin_match("alien_meow", "doge", "local_2p", "gate3-hash")
    for frame in range(1, 121):
        var a := InputFrame.neutral(frame)
        var b := InputFrame.neutral(frame)
        observed.simulate_frame(a, b)
        control.simulate_frame(a, b)
        aggregator.observe(observed.drain_events(), observed)
        control.drain_events()
    t.equal(observed.state_signature(), control.state_signature(), "Telemetry observation does not alter authoritative BattleState hash")

func _test_sink_failure_isolated() -> void:
    var service := TelemetryService.new()
    var configured := service.configure("gate3-install", "gate3-session", "res://project.godot/not-a-directory", 8, "gate3", "gate3", "test")
    t.that(not configured, "Invalid telemetry sink configuration is reported without combat mutation")
    var battle := _battle(&"alien_meow", &"doge")
    var before := battle.state_signature()
    service.observe_combat_events([], battle)
    t.equal(battle.state_signature(), before, "Unconfigured/failing telemetry path leaves authoritative state unchanged")
