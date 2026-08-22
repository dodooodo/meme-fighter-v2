# M7 restore/resimulation and replay must regenerate identical presentation-significant IDs.
class_name PresentationReplayResimTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    _test_snapshot_resim_event_ids_identical()
    _test_replay_event_ids_and_final_hash_identical()
    print("\nM7 presentation replay/resim tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _ids(events: Array[CombatEvent]) -> PackedStringArray:
    var ids := PackedStringArray()
    for event: CombatEvent in events:
        ids.append(PresentationEventId.canonical(event))
    return ids

func _test_snapshot_resim_event_ids_identical() -> void:
    var battle := BattleSimulation.new()
    battle.configure(generic, rush, null, null, Vector2i(50000, 56000), Vector2i(57000, 56000))
    battle.simulate_frame(InputFrame.with_light_press(1), InputFrame.neutral(1))
    battle.drain_events()
    var snapshot := battle.capture_state()
    for frame in range(2, 8):
        battle.simulate_frame(InputFrame.neutral(frame), InputFrame.neutral(frame))
    var ids_a := _ids(battle.drain_events())
    t.that(battle.restore_state(snapshot), "Snapshot restores before presentation-significant HIT")
    for frame in range(2, 8):
        battle.simulate_frame(InputFrame.neutral(frame), InputFrame.neutral(frame))
    var ids_b := _ids(battle.drain_events())
    t.equal(ids_b, ids_a, "Snapshot restore + identical resimulation regenerates identical presentation event IDs")

func _test_replay_event_ids_and_final_hash_identical() -> void:
    var a := BattleSimulation.new()
    a.configure(generic, rush, null, null, Vector2i(50000, 56000), Vector2i(57000, 56000))
    var recorder := ReplayRecorder.new()
    recorder.begin_recording(&"versus", generic.id, rush.id, 0)
    a.set_replay_recorder(recorder)
    var ids_a := PackedStringArray()
    for frame in range(1, 20):
        var p1 := InputFrame.with_light_press(frame) if frame == 1 else InputFrame.neutral(frame)
        a.simulate_frame(p1, InputFrame.neutral(frame))
        ids_a.append_array(_ids(a.drain_events()))
    var hash_a := a.state_signature()
    recorder.finish_recording(hash_a)
    var replay := recorder.replay_data()
    var source_a := ReplayInputSource.new()
    var source_b := ReplayInputSource.new()
    source_a.configure(replay, 1)
    source_b.configure(replay, 2)
    var b := BattleSimulation.new()
    b.configure(generic, rush, source_a, source_b, Vector2i(50000, 56000), Vector2i(57000, 56000))
    var ids_b := PackedStringArray()
    for _i in range(replay.frame_count()):
        b.sample_and_simulate_frame()
        ids_b.append_array(_ids(b.drain_events()))
    t.equal(ids_b, ids_a, "Fresh replay playback regenerates identical presentation-significant event ID sequence")
    t.equal(b.state_signature(), hash_a, "Presentation event payload extension does not change deterministic replay final gameplay hash")
