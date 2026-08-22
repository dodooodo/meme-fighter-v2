# Responsibility: M8C authoritative CPU InputFrame recording/replay determinism regression.
class_name M8CpuReplayTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_cpu_replay_records_input_not_decisions()
    _test_charge_press_hold_release_replay()
    print("\nM8C CPU/Charge replay tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_cpu_replay_records_input_not_decisions() -> void:
    var generic := load("res://data/characters/generic_fighter.tres") as CharacterData
    var zone := load("res://data/characters/zone_fighter.tres") as CharacterData
    var cpu := CpuInputSource.new()
    cpu.set_fixed_seed(20260820)
    var live := BattleSimulation.new()
    live.configure(generic, zone, null, cpu)
    t.that(cpu.bind_context(live.fighter_b, live.fighter_a, live), "CPU replay setup binds context")
    var recorder := ReplayRecorder.new()
    t.that(recorder.begin_recording(&"versus", generic.id, zone.id), "ReplayRecorder begins canonical CPU match recording")
    live.set_replay_recorder(recorder)
    for _i in range(600):
        live.sample_and_simulate_frame()
        if live.round_controller.is_match_over():
            break
    var live_hash := live.state_signature()
    t.that(recorder.finish_recording(live_hash), "CPU replay recording finishes with final gameplay hash")
    var replay := recorder.replay_data()
    t.that(replay.frame_count() > 0, "CPU replay stores authoritative frame pairs")
    t.equal(replay.combat_rules_version, ReplayFormat.COMBAT_RULES_VERSION, "CPU replay uses current combat-rules compatibility version")

    var p1 := ReplayInputSource.new()
    var p2 := ReplayInputSource.new()
    t.that(p1.configure(replay, 1) and p2.configure(replay, 2), "ReplayInputSource configures both recorded participants")
    var playback := BattleSimulation.new()
    playback.configure(generic, zone, p1, p2)
    for _i in range(replay.frame_count()):
        playback.sample_and_simulate_frame()
    t.equal(playback.state_signature(), live_hash, "Recorded CPU canonical InputFrames reproduce identical BattleStateHasher signature without rerunning AI")

func _test_charge_press_hold_release_replay() -> void:
    var generic := load("res://data/characters/generic_fighter.tres") as CharacterData
    var live := BattleSimulation.new()
    live.configure(generic, generic)
    var recorder := ReplayRecorder.new()
    t.that(recorder.begin_recording(&"versus", generic.id, generic.id), "Charge replay recorder begins")
    live.set_replay_recorder(recorder)
    var special := InputFrame.InputButton.SPECIAL
    for frame in range(1, 76):
        var p1: InputFrame
        if frame == 1:
            p1 = InputFrame.new(frame, 0, 0, special, special, 0)
        elif frame <= 60:
            p1 = InputFrame.new(frame, 0, 0, special, 0, 0)
        elif frame == 61:
            p1 = InputFrame.new(frame, 0, 0, 0, 0, special)
        else:
            p1 = InputFrame.neutral(frame)
        live.simulate_frame(p1, InputFrame.neutral(frame))
    t.equal(live.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL_L3, "Recorded 60F hold naturally derives Lv3 without replay metadata")
    var live_hash := live.state_signature()
    t.that(recorder.finish_recording(live_hash), "Charge replay recording finishes")
    var replay := recorder.replay_data()
    var p1_source := ReplayInputSource.new()
    var p2_source := ReplayInputSource.new()
    p1_source.configure(replay, 1)
    p2_source.configure(replay, 2)
    var playback := BattleSimulation.new()
    playback.configure(generic, generic, p1_source, p2_source)
    for _i in range(replay.frame_count()):
        playback.sample_and_simulate_frame()
    t.equal(playback.state_signature(), live_hash, "Replay press/hold/release derives same Lv3 state and final hash")
