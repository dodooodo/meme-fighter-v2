# Responsibility: M6 random-access ReplayInputSource exact playback/EOF and recorder ordering lifecycle tests.
class_name ReplayInputSourceTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_recorder_and_random_access_input_source()
    _test_recorder_duplicate_and_finish_rules()
    print("\nM6 ReplayInputSource tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_recorder_and_random_access_input_source() -> void:
    var recorder := ReplayRecorder.new()
    t.that(recorder.begin_recording(&"versus", &"zone_fighter", &"rush_grappler", 99), "ReplayRecorder begins from explicit authoritative initial frame")
    var light := InputFrame.InputButton.LIGHT
    var p1_100 := InputFrame.new(100, 0, -1, light, light, 0)
    var p2_100 := InputFrame.neutral(100)
    var p1_101 := InputFrame.new(101, 0, 0, 0, 0, light)
    var p2_101 := InputFrame.new(101, 1, 0, 0, 0, 0)
    t.that(recorder.record_frame(p1_100, p2_100), "Recorder accepts exact next authoritative frame 100")
    t.that(recorder.record_frame(p1_101, p2_101), "Recorder accepts exact next authoritative frame 101")
    t.that(recorder.finish_recording("finalhash"), "Recorder finishes once with final BattleStateHasher string")
    var replay := recorder.replay_data()
    var source := ReplayInputSource.new()
    t.that(source.configure(replay, 1), "ReplayInputSource configures participant P1")
    var f100 := source.sample(100)
    t.equal(f100.direction_y, -1, "ReplayInputSource random-access returns exact Down direction")
    t.equal(f100.pressed_bits, light, "ReplayInputSource returns exact LIGHT pressed edge")
    var f101 := source.sample(101)
    t.equal(f101.released_bits, light, "ReplayInputSource returns exact LIGHT released edge rather than deriving from held")
    var again100 := source.sample(100)
    t.equal(again100.pressed_bits, light, "ReplayInputSource can re-request old frame without mutable cursor truth")
    var eof := source.sample(102)
    t.equal(eof.held_bits, 0, "Replay EOF returns neutral InputFrame")
    t.that(source.eof_reached, "ReplayInputSource exposes EOF diagnostic after request past last frame")

func _test_recorder_duplicate_and_finish_rules() -> void:
    var recorder := ReplayRecorder.new()
    recorder.begin_recording(&"versus", &"generic_fighter", &"rush_grappler", 0)
    t.that(recorder.record_frame(InputFrame.neutral(1), InputFrame.neutral(1)), "Recorder accepts frame 1")
    t.that(not recorder.record_frame(InputFrame.neutral(1), InputFrame.neutral(1)), "Recorder rejects duplicate frame instead of appending")
    t.that(not recorder.record_frame(InputFrame.neutral(3), InputFrame.neutral(3)), "Recorder rejects frame gap")
    t.that(recorder.finish_recording("hash"), "Recorder can finish non-empty recording")
    t.that(not recorder.finish_recording("hash2"), "Recorder finish is one-shot")
    t.that(not recorder.record_frame(InputFrame.neutral(2), InputFrame.neutral(2)), "Finished recorder does not append")
    var empty := ReplayRecorder.new()
    empty.begin_recording(&"versus", &"generic_fighter", &"rush_grappler", 0)
    t.that(not empty.finish_recording("hash"), "Empty recording cannot become valid playback replay")
