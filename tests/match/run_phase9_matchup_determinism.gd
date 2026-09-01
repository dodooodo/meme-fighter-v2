# Phase 9: real 14x14 BattleSimulation integration matrix plus deterministic
# replay stress. Fixtures only set contact positions/meter so real normalized
# InputFrames drive every checked state transition.
extends SceneTree

const STRESS_SCENARIOS: Array[Array] = [
    [&"doge", &"alien_meow"],
    [&"pink_star", &"bao_la"],
    [&"tempura_penguin", &"magic_orange_cat"],
    [&"sauce_stubble_dog", &"niu_lai"],
    [&"scared_cat", &"scared_cat"],
    [&"goblin_love", &"ok_meow_boss"],
    [&"blade_shield", &"ya_mouse"],
    [&"salad_cat", &"alien_meow"],
    [&"bao_la", &"pink_star"],
    [&"magic_orange_cat", &"tempura_penguin"],
]

var failures := 0
var matrix_passed := 0
var matrix_failed: Array[String] = []
var stress_hash_a := ""
var stress_hash_b := ""
var auxiliary_coverage: Dictionary = {}

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _run_matrix()
    _run_determinism_stress()
    print("\nPhase 9 matchup matrix: %d / 196 PASS" % matrix_passed)
    print("Phase 9 determinism stress: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)

func _run_matrix() -> void:
    _check(RosterRegistry.count() == 14, "RosterRegistry supplies all 14 matrix participants")
    for a_entry: Dictionary in RosterRegistry.ENTRIES:
        for b_entry: Dictionary in RosterRegistry.ENTRIES:
            var a := a_entry["character"] as CharacterData
            var b := b_entry["character"] as CharacterData
            var a_presentation := a_entry["presentation"] as CharacterPresentationData
            var b_presentation := b_entry["presentation"] as CharacterPresentationData
            var label := "%s vs %s" % [String(a_entry["id"]), String(b_entry["id"])]
            var stage := _run_pair(a, b, a_presentation, b_presentation)
            if stage.is_empty():
                matrix_passed += 1
                print("[PASS] Matrix %s" % label)
            else:
                matrix_failed.append("%s | %s" % [label, stage])
                _check(false, "Matrix %s failed at %s" % [label, stage])

func _run_pair(a: CharacterData, b: CharacterData, presentation_a: CharacterPresentationData, presentation_b: CharacterPresentationData) -> String:
    if a == null or b == null or a.move_set == null or b.move_set == null:
        return "CharacterData / MoveSet load"
    if presentation_a == null or presentation_b == null or presentation_a.character_id != a.id or presentation_b.character_id != b.id:
        return "presentation resolution"
    var profile_a := CpuProfileRegistry.profile_for(a.id)
    var profile_b := CpuProfileRegistry.profile_for(b.id)
    if profile_a == null or profile_b == null or not profile_a.is_valid() or not profile_b.is_valid():
        return "CPU profile resolution"

    var battle := BattleSimulation.new()
    battle.configure_standard(a, b)
    if battle.fighter_a == null or battle.fighter_b == null or battle.fighter_a.data != a or battle.fighter_b.data != b:
        return "BattleSimulation configuration"
    if battle.fighter_a.movement_motor.sim_position != battle.configured_start_position(1) or battle.fighter_b.movement_motor.sim_position != battle.configured_start_position(2):
        return "canonical spawn"
    if FighterPresentationResolver.resolve_animation(battle.fighter_a, presentation_a) == &"" or FighterPresentationResolver.resolve_animation(battle.fighter_b, presentation_b) == &"":
        return "presentation animation resolver"
    if not _exercise_fighter(battle, 1):
        return "P1 movement / Light / Heavy / Low / Special / Ultimate"
    if not _exercise_fighter(battle, 2):
        return "P2 movement / Light / Heavy / Low / Special / Ultimate"
    if not _snapshot_hash_replay(battle):
        return "Snapshot capture / restore / BattleStateHasher"
    battle.reset_full_match()
    if battle.fighter_a.movement_motor.sim_position != battle.configured_start_position(1) or battle.fighter_b.movement_motor.sim_position != battle.configured_start_position(2):
        return "round reset"
    return ""

func _exercise_fighter(battle: BattleSimulation, fighter_id: int) -> bool:
    battle.reset_full_match()
    var fighter := battle.fighter_by_id(fighter_id)
    var start_x := fighter.movement_motor.sim_position.x
    _tick_for(battle, fighter_id, InputFrame.new(battle.frame_number + 1, 1 if fighter_id == 1 else -1))
    if fighter.movement_motor.sim_position.x == start_x:
        return false
    for action: StringName in [&"light", &"heavy", &"low"]:
        battle.reset_full_match()
        _place_at_contact(battle)
        var input := _action_input(battle.frame_number + 1, fighter_id, action)
        _tick_for(battle, fighter_id, input)
        if fighter.move_runner.current_move_id() == &"":
            return false
    battle.reset_full_match()
    _place_at_contact(battle)
    for held_frame in range(1, 4):
        _tick_for(battle, fighter_id, _special_input(battle.frame_number + 1, true, held_frame == 1, false))
    _tick_for(battle, fighter_id, _special_input(battle.frame_number + 1, false, false, true))
    if not fighter.move_runner.current_move_id().ends_with("_l1"):
        return false
    battle.reset_full_match()
    _place_at_contact(battle)
    fighter.meter.set_value(100)
    _tick_for(battle, fighter_id, InputFrame.with_ultimate_press(battle.frame_number + 1))
    if fighter.move_runner.current_move_id() != MoveIds.ULTIMATE:
        return false
    return true

func _snapshot_hash_replay(battle: BattleSimulation) -> bool:
    battle.reset_full_match()
    _place_at_contact(battle)
    _tick_for(battle, 1, InputFrame.with_light_press(battle.frame_number + 1), InputFrame.new(battle.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD, InputFrame.InputButton.GUARD, 0))
    var snapshot := battle.capture_state()
    var replay: Array[Dictionary] = []
    for index in range(8):
        var frame := battle.frame_number + 1
        replay.append({
            "a": _action_input(frame, 1, &"heavy") if index == 2 else InputFrame.neutral(frame),
            "b": _action_input(frame, 2, &"low") if index == 5 else InputFrame.neutral(frame),
        })
        battle.simulate_frame(replay[-1]["a"], replay[-1]["b"])
    var hash_a := battle.state_signature()
    if hash_a.is_empty() or not battle.restore_state(snapshot):
        return false
    for item: Dictionary in replay:
        battle.simulate_frame(item["a"], item["b"])
    return battle.state_signature() == hash_a

func _run_determinism_stress() -> void:
    var first := _run_stress_once()
    var second := _run_stress_once()
    stress_hash_a = String(first["hash"])
    stress_hash_b = String(second["hash"])
    auxiliary_coverage = first["coverage"] as Dictionary
    var coverage_keys: Array = auxiliary_coverage.keys()
    coverage_keys.sort()
    print("Phase 9 auxiliary state coverage: %s" % ", ".join(coverage_keys))
    print("Phase 9 stress hash A: %s" % stress_hash_a)
    print("Phase 9 stress hash B: %s" % stress_hash_b)
    _check(int(first["ticks"]) == 10000 and int(second["ticks"]) == 10000, "Determinism stress executes two identical 10,000-tick authoritative runs")
    _check(String(first["error"]).is_empty() and String(second["error"]).is_empty(), "Stress snapshots restore and replay at every checkpoint")
    _check(stress_hash_a == stress_hash_b and not stress_hash_a.is_empty(), "Repeated 10,000-tick stress run ends at an identical BattleStateHasher value")

func _run_stress_once() -> Dictionary:
    var hashes: PackedStringArray = []
    var coverage: Dictionary = {}
    var ticks := 0
    var error := ""
    for scenario: Array in STRESS_SCENARIOS:
        var battle := BattleSimulation.new()
        var rules := MatchRulesData.versus_defaults()
        rules.rounds_to_win = 99
        rules.round_timer_frames = 360
        rules.post_round_frames = 6
        battle.configure_standard(RosterRegistry.character_by_id(scenario[0]), RosterRegistry.character_by_id(scenario[1]), null, null, rules)
        _place_at_contact(battle)
        battle.fighter_a.meter.set_value(100)
        battle.fighter_b.meter.set_value(100)
        for step in range(1, 1001):
            var frame := battle.frame_number + 1
            battle.simulate_frame(_stress_input(frame, 1), _stress_input(frame, -1))
            ticks += 1
            _observe_auxiliary_state(battle, coverage)
            if step in [251, 501, 751] and error.is_empty():
                var checkpoint_error := _stress_snapshot_checkpoint(battle)
                if not checkpoint_error.is_empty():
                    error = "%s at %s/%s F%d" % [checkpoint_error, String(scenario[0]), String(scenario[1]), step]
        hashes.append(battle.state_signature())
    return {"ticks": ticks, "hash": "|".join(hashes).sha256_text(), "coverage": coverage, "error": error}

func _stress_snapshot_checkpoint(battle: BattleSimulation) -> String:
    var snapshot := battle.capture_state()
    var replay: Array[Dictionary] = []
    for index in range(12):
        var frame := battle.frame_number + 1
        var a := _stress_input(frame, 1)
        var b := _stress_input(frame, -1)
        replay.append({"a": a, "b": b})
        battle.simulate_frame(a, b)
    var expected_hash := battle.state_signature()
    if not battle.restore_state(snapshot):
        return "restore rejected snapshot"
    for item: Dictionary in replay:
        battle.simulate_frame(item["a"], item["b"])
    return "" if battle.state_signature() == expected_hash else "replay hash mismatch"

func _observe_auxiliary_state(battle: BattleSimulation, coverage: Dictionary) -> void:
    for fighter: Fighter in [battle.fighter_a, battle.fighter_b]:
        var snapshot: FighterStateSnapshot = FighterSnapshotCodec.capture(fighter)
        if not snapshot.status_states.is_empty(): coverage["status"] = true
        if not snapshot.mode_state.is_empty(): coverage["mode"] = true
        if not snapshot.resource_values.is_empty(): coverage["resource"] = true
        if not snapshot.mechanics_state.is_empty(): coverage["mechanics"] = true
    if not battle.projectile_system.active_projectiles().is_empty(): coverage["projectile"] = true
    if not battle.temporary_entity_system.active_entities().is_empty(): coverage["temporary_entity"] = true

func _stress_input(frame: int, toward: int) -> InputFrame:
    var phase := frame % 120
    if phase == 1:
        return InputFrame.with_ultimate_press(frame)
    if phase == 18:
        return InputFrame.with_light_press(frame)
    if phase == 28:
        return InputFrame.with_heavy_press(frame, toward)
    if phase == 38:
        return InputFrame.with_light_press(frame, 0, -1)
    if phase == 50:
        return _special_input(frame, true, true, false)
    if phase >= 51 and phase <= 102:
        return _special_input(frame, true, false, false)
    if phase == 103:
        return _special_input(frame, false, false, true)
    if phase >= 108 and phase <= 112:
        return InputFrame.new(frame, 0, 0, InputFrame.InputButton.GUARD, InputFrame.InputButton.GUARD if phase == 108 else 0, 0)
    return InputFrame.neutral(frame)

func _action_input(frame: int, fighter_id: int, action: StringName) -> InputFrame:
    match action:
        &"light": return InputFrame.with_light_press(frame)
        &"heavy": return InputFrame.with_heavy_press(frame)
        &"low": return InputFrame.with_light_press(frame, 0, -1)
    return InputFrame.neutral(frame)

func _special_input(frame: int, held: bool, pressed: bool, released: bool) -> InputFrame:
    var bit := InputFrame.InputButton.SPECIAL
    return InputFrame.new(frame, 0, 0, bit if held else 0, bit if pressed else 0, bit if released else 0)

func _tick_for(battle: BattleSimulation, fighter_id: int, input: InputFrame, other: InputFrame = null) -> void:
    var neutral := InputFrame.neutral(battle.frame_number + 1)
    battle.simulate_frame(input if fighter_id == 1 else (other if other != null else neutral), input if fighter_id == 2 else (other if other != null else neutral))

func _place_at_contact(battle: BattleSimulation) -> void:
    battle.fighter_a.movement_motor.sim_position = Vector2i(50000, BattleSimulation.GROUND_Y_UNITS)
    battle.fighter_b.movement_motor.sim_position = Vector2i(55000, BattleSimulation.GROUND_Y_UNITS)
    battle.fighter_a.movement_motor.facing = 1
    battle.fighter_b.movement_motor.facing = -1

func _check(condition: bool, message: String) -> void:
    if condition:
        print("[PASS] ", message)
    else:
        failures += 1
        push_error("[FAIL] " + message)
