# Responsibility: M6 fresh-Battle input-only deterministic replay across projectile combat, round reset, match lifecycle and final hash.
class_name ReplayDeterminismTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var rush: CharacterData
var generic: CharacterData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_projectile_round_transition_fresh_battle_hash()
    _test_dash_reconstruction_from_input_history()
    _test_metadata_mismatch_rejected()
    print("\nM6 Replay Determinism tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _fast_versus_rules() -> MatchRulesData:
    var rules := MatchRulesData.versus_defaults()
    rules.round_timer_frames = 40
    rules.post_round_frames = 2
    return rules

func _scripted_p1(frame: int) -> InputFrame:
    if frame == 1 or frame == 50:
        return InputFrame.with_special_press(frame)
    return InputFrame.neutral(frame)

func _test_projectile_round_transition_fresh_battle_hash() -> void:
    var rules_a := _fast_versus_rules()
    var battle_a := BattleSimulation.new()
    battle_a.configure(zone, rush, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS), rules_a)
    var recorder := ReplayRecorder.new()
    t.that(recorder.begin_recording(rules_a.id, zone.id, rush.id, battle_a.frame_number), "Determinism recorder starts from fresh Battle frame zero")
    battle_a.set_replay_recorder(recorder)
    for frame in range(1, 121):
        battle_a.simulate_frame(_scripted_p1(frame), InputFrame.neutral(frame))
    var hash_a := battle_a.state_signature()
    t.that(recorder.finish_recording(hash_a), "Replay recording finishes with BattleStateHasher final hash")
    var replay := recorder.replay_data()
    t.equal(replay.frame_count(), 120, "Replay records one complete normalized pair for all 120 simulation frames")
    t.that(battle_a.projectile_system.next_projectile_instance_serial >= 3, "Scripted recording reconstructed multiple projectile instances across rounds")
    t.that(battle_a.round_controller.round_number >= 2 or battle_a.round_controller.is_match_over(), "Scripted recording crosses at least one round reset")

    var source_p1 := ReplayInputSource.new()
    var source_p2 := ReplayInputSource.new()
    source_p1.configure(replay, 1)
    source_p2.configure(replay, 2)
    var rules_b := _fast_versus_rules()
    var battle_b := BattleSimulation.new()
    battle_b.configure(zone, rush, source_p1, source_p2, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS), rules_b)
    t.that(ReplayValidator.validate_for_simulation(replay, battle_b), "Replay metadata validates against caller-configured fresh Battle")
    for _i in range(replay.frame_count()):
        battle_b.sample_and_simulate_frame()
    t.equal(battle_b.frame_number, replay.final_frame_number(), "Playback consumes every authoritative replay frame")
    t.equal(battle_b.projectile_system.next_projectile_instance_serial, battle_a.projectile_system.next_projectile_instance_serial, "Playback reconstructs deterministic projectile instance IDs")
    t.equal(battle_b.round_controller.round_number, battle_a.round_controller.round_number, "Playback reconstructs same round transition state")
    t.equal(battle_b.round_controller.p1_round_wins, battle_a.round_controller.p1_round_wins, "Playback reconstructs same round wins")
    t.equal(battle_b.state_signature(), replay.expected_final_state_hash, "Fresh Battle + recorded InputFrames reproduces exact final BattleStateHash")
    t.that(ReplayValidator.final_hash_matches(replay, battle_b), "ReplayValidator reports expected final hash match")

func _test_dash_reconstruction_from_input_history() -> void:
    var rules := MatchRulesData.versus_defaults()
    rules.round_timer_frames = 600
    var battle_a := BattleSimulation.new()
    battle_a.configure(generic, rush, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(90000, BattleSimulation.GROUND_Y_UNITS), rules)
    var recorder := ReplayRecorder.new()
    recorder.begin_recording(&"versus", generic.id, rush.id, 0)
    battle_a.set_replay_recorder(recorder)
    var sequence := [
        InputFrame.new(1, 1, 0, 0, 0, 0),
        InputFrame.neutral(2),
        InputFrame.new(3, 1, 0, 0, 0, 0),
    ]
    for frame: InputFrame in sequence:
        battle_a.simulate_frame(frame, InputFrame.neutral(frame.frame_number))
    var expected_state := battle_a.fighter_a.state_machine.state
    recorder.finish_recording(battle_a.state_signature())
    var replay := recorder.replay_data()
    var source_a := ReplayInputSource.new()
    var source_b := ReplayInputSource.new()
    source_a.configure(replay, 1)
    source_b.configure(replay, 2)
    var battle_b := BattleSimulation.new()
    battle_b.configure(generic, rush, source_a, source_b, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(90000, BattleSimulation.GROUND_Y_UNITS), rules)
    for _i in range(replay.frame_count()):
        battle_b.sample_and_simulate_frame()
    t.equal(expected_state, FighterStateMachine.State.DASH_FORWARD, "Recorded Forward-Neutral-Forward derives Dash in original simulation")
    t.equal(battle_b.fighter_a.state_machine.state, expected_state, "Replay Inputs rebuild InputHistory and derive same Dash without storing ActionIntent")

func _test_metadata_mismatch_rejected() -> void:
    var recorder := ReplayRecorder.new()
    recorder.begin_recording(&"versus", zone.id, rush.id, 0)
    recorder.record_frame(InputFrame.neutral(1), InputFrame.neutral(1))
    recorder.finish_recording("hash")
    var replay := recorder.replay_data()
    var correct := BattleSimulation.new()
    correct.configure(zone, rush, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS), MatchRulesData.versus_defaults())
    t.that(ReplayValidator.validate_for_simulation(replay, correct), "Replay validates matching characters/rules/stage/version")
    var wrong_character := BattleSimulation.new()
    wrong_character.configure(generic, rush, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS), MatchRulesData.versus_defaults())
    t.that(not ReplayValidator.validate_for_simulation(replay, wrong_character), "Replay character mismatch is rejected without auto-loading CharacterData")
    var wrong_rules := BattleSimulation.new()
    wrong_rules.configure(zone, rush, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS), MatchRulesData.training_defaults())
    t.that(not ReplayValidator.validate_for_simulation(replay, wrong_rules), "Versus replay cannot silently play under Training MatchRules")
