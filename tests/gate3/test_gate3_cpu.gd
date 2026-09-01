# Gate 3 CPU data/determinism tests. CPU remains an InputSource and never receives gameplay authority.
class_name Gate3CpuTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_difficulties()
    _test_fourteen_profiles()
    _test_profiles_are_distinct()
    _test_cpu_is_input_source_and_deterministic()
    _test_ground_air_observation_uses_fighter_facade()
    _test_mode_guard_legality()
    print("\nGate 3 CPU tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_difficulties() -> void:
    var expected := {
        &"beginner": [24, 36, 30],
        &"normal": [15, 24, 18],
        &"hard": [9, 15, 8],
        &"expert": [6, 10, 4],
    }
    for id: StringName in expected.keys():
        var difficulty := CpuProfileRegistry.difficulty_for(id)
        t.that(difficulty != null and difficulty.is_valid(), "CPU difficulty loads/validates: %s" % String(id))
        if difficulty == null:
            continue
        var values: Array = expected[id]
        t.equal(difficulty.reaction_min_frames, int(values[0]), "%s reaction minimum" % String(id))
        t.equal(difficulty.reaction_max_frames, int(values[1]), "%s reaction maximum" % String(id))
        t.equal(difficulty.decision_error_percent, int(values[2]), "%s decision error" % String(id))

func _test_fourteen_profiles() -> void:
    t.equal(RosterRegistry.count(), 14, "CPU profile test uses 14-character roster")
    for item: Dictionary in RosterRegistry.ENTRIES:
        var character_id := StringName(item["id"])
        var profile := CpuProfileRegistry.profile_for(character_id)
        t.that(profile != null and profile.is_valid(), "CPU utility profile exists/valid: %s" % String(character_id))
        if profile != null:
            t.equal(profile.character_id, character_id, "CPU profile stable character ID: %s" % String(character_id))
            t.that(not profile.archetype.is_empty(), "CPU profile has archetype: %s" % String(character_id))

func _test_profiles_are_distinct() -> void:
    var signatures: Dictionary = {}
    for item: Dictionary in RosterRegistry.ENTRIES:
        var profile := CpuProfileRegistry.profile_for(StringName(item["id"]))
        if profile == null:
            continue
        var signature := "%d:%d:%d:%d:%d:%d:%d" % [profile.preferred_range_min_units, profile.preferred_range_max_units, profile.approach_weight, profile.retreat_weight, profile.throw_weight, profile.trap_weight, profile.counter_weight]
        signatures[signature] = true
    t.that(signatures.size() >= 12, "Roster CPU profiles express materially distinct utility preferences")

func _make_cpu_battle(character_id: StringName, seed: int) -> Dictionary:
    var data := RosterRegistry.character_by_id(character_id)
    var cpu := CpuInputSource.new()
    cpu.set_fixed_seed(seed)
    var battle := BattleSimulation.new()
    battle.configure(data, data, null, cpu, Vector2i(36000, BattleSimulation.GROUND_Y_UNITS), Vector2i(72000, BattleSimulation.GROUND_Y_UNITS))
    var bound := cpu.bind_context(battle.fighter_b, battle.fighter_a, battle)
    return {"battle": battle, "cpu": cpu, "bound": bound}

func _test_cpu_is_input_source_and_deterministic() -> void:
    t.that(CpuInputSource.new() is InputSource, "CPU remains an InputSource")
    var a := _make_cpu_battle(&"alien_meow", 777)
    var b := _make_cpu_battle(&"alien_meow", 777)
    t.that(bool(a["bound"]) and bool(b["bound"]), "CPU binds read-only battle context/profile")
    var sequence_a: Array[String] = []
    var sequence_b: Array[String] = []
    for frame in range(1, 181):
        sequence_a.append(_input_key((a["cpu"] as CpuInputSource).sample(frame)))
        sequence_b.append(_input_key((b["cpu"] as CpuInputSource).sample(frame)))
    t.equal(sequence_a, sequence_b, "Same seed + equivalent visible state produces identical CPU InputFrames")
    var cpu := a["cpu"] as CpuInputSource
    t.that(cpu.last_reaction_frames() >= 15 and cpu.last_reaction_frames() <= 24, "Normal CPU reaction remains inside authored 15-24F window")

func _test_ground_air_observation_uses_fighter_facade() -> void:
    var setup := _make_cpu_battle(&"alien_meow", 778)
    var battle := setup["battle"] as BattleSimulation
    var cpu := setup["cpu"] as CpuInputSource
    cpu._remember_observation(0)
    var grounded: Dictionary = cpu._observation_history[0]
    t.that(bool(grounded["own_grounded"]) and not bool(grounded["own_airborne"]), "CPU observes own grounded state through Fighter facade")
    t.that(bool(grounded["opponent_grounded"]) and not bool(grounded["opponent_airborne"]), "CPU observes opponent grounded state through Fighter facade")
    battle.simulate_frame(InputFrame.new(1, 0, 1, 0, 0, 0), InputFrame.new(1, 0, 1, 0, 0, 0))
    cpu._remember_observation(1)
    var airborne: Dictionary = cpu._observation_history[1]
    t.that(bool(airborne["own_airborne"]) and not bool(airborne["own_grounded"]), "CPU observes own airborne state through Fighter facade")
    t.that(bool(airborne["opponent_airborne"]) and not bool(airborne["opponent_grounded"]), "CPU observes opponent airborne state through Fighter facade")

func _test_mode_guard_legality() -> void:
    var setup := _make_cpu_battle(&"blade_shield", 901)
    var battle := setup["battle"] as BattleSimulation
    var cpu := setup["cpu"] as CpuInputSource
    var entered := battle.fighter_b.mode.enter(&"dual_blade", -1, battle.frame_number)
    t.that(entered, "Blade CPU test can enter authored Dual mode")
    var guard_frame := cpu._frame_for_decision(1, 0, &"guard")
    t.that(not guard_frame.is_held(InputFrame.InputButton.GUARD), "CPU does not bypass Dual mode guard_allowed=false")

func _input_key(input: InputFrame) -> String:
    return "%d:%d:%d:%d:%d:%d" % [input.frame_number, input.direction_x, input.direction_y, input.held_bits, input.pressed_bits, input.released_bits]
