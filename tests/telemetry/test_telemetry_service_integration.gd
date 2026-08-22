# Responsibility: A4 service/sink/replay correlation integration and determinism boundary tests.
class_name TelemetryServiceIntegrationTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_service_writes_correlated_envelopes()
    _test_replay_store_roundtrip()
    _test_battle_scene_finalization_smoke()
    _test_observation_and_sink_failure_do_not_change_hash()
    print("\nA4 telemetry integration tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle() -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(load("res://data/characters/generic_fighter.tres"), load("res://data/characters/zone_fighter.tres"))
    return battle

func _test_service_writes_correlated_envelopes() -> void:
    var directory := OS.get_temp_dir().path_join("meme_fighter_a4_service")
    var service := TelemetryService.new()
    t.that(service.configure("installation-test", "session-test", directory, 64, "build-test", "content-test", "test"), "Telemetry service configures explicit local context")
    var battle := _battle()
    service.begin_match("generic_fighter", "zone_fighter", "local_2p", "replay-test", 0, "match-test")
    service.observe_combat_events([CombatEvent.round_started(0, 1), CombatEvent.move_started(1, 1, &"stand_light", 1000001)], battle)
    service.record_load_duration(4.0)
    service.record_asset_pack_load_duration(2.0)
    service.record_error("TEST", "contained", false)
    battle.frame_number = 60
    service.end_match("reset", battle, {"replay_id": "replay-test", "replay_path": "user://replays/replay-test.tbf_replay.json", "replay_saved": true})
    t.that(service.flush_blocking(999), "Service flushes all queued envelopes at an explicit lifecycle boundary")

    var path := service.output_path()
    var file := FileAccess.open(path, FileAccess.READ)
    var names: Array[String] = []
    var match_summary: Dictionary = {}
    while file != null and file.get_position() < file.get_length():
        var parsed: Variant = JSON.parse_string(file.get_line())
        if typeof(parsed) == TYPE_DICTIONARY:
            names.append(str(parsed.get("event_name", "")))
            if parsed.get("event_name", "") == "match.completed":
                match_summary = parsed
    if file != null:
        file.close()
    for expected in ["performance.load_duration", "performance.asset_pack_load_duration", "performance.error", "move.summary", "match.completed"]:
        t.that(names.has(expected), "JSONL integration contains %s" % expected)
    t.equal(match_summary.get("match_id", ""), "match-test", "Match envelope carries match correlation")
    t.equal(match_summary.get("payload", {}).get("replay_id", ""), "replay-test", "Match payload carries replay correlation")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
    DirAccess.remove_absolute(directory)

func _test_replay_store_roundtrip() -> void:
    var battle := _battle()
    var recorder := ReplayRecorder.new()
    recorder.begin_recording(&"versus", battle.fighter_a.data.id, battle.fighter_b.data.id)
    battle.set_replay_recorder(recorder)
    battle.simulate_frame(InputFrame.neutral(1), InputFrame.neutral(1))
    t.that(recorder.finish_recording(battle.state_signature()), "Replay fixture finishes with authoritative hash")
    var directory := OS.get_temp_dir().path_join("meme_fighter_a4_replays")
    var correlation := TelemetryReplayStore.save("replay-test", recorder.replay_data(), directory)
    t.equal(correlation.get("replay_id", ""), "replay-test", "Replay correlation retains stable ID")
    t.equal(correlation.get("replay_saved", false), true, "Replay correlation reports successful persistence")
    var loaded := ReplayCodec.load_from_file(correlation.get("replay_path", ""))
    t.that(loaded != null and loaded.expected_final_state_hash == battle.state_signature(), "Correlated replay file round-trips")
    if FileAccess.file_exists(correlation.get("replay_path", "")):
        DirAccess.remove_absolute(correlation.get("replay_path", ""))
    DirAccess.remove_absolute(directory)

func _test_observation_and_sink_failure_do_not_change_hash() -> void:
    var observed := _battle()
    var control := _battle()
    var service := TelemetryService.new()
    t.that(not service.configure("installation-test", "session-test", "res://project.godot", 4, "build", "content", "test"), "Invalid sink setup is reported")
    service.begin_match("generic_fighter", "zone_fighter", "local_2p", "replay-test", 0, "match-test")
    for frame in range(1, 31):
        var p1 := InputFrame.with_light_press(frame) if frame == 1 else InputFrame.neutral(frame)
        var p2 := InputFrame.neutral(frame)
        observed.simulate_frame(p1, p2)
        control.simulate_frame(p1, p2)
        service.observe_combat_events(observed.drain_events(), observed)
        control.drain_events()
    t.equal(observed.state_signature(), control.state_signature(), "Telemetry observation and sink failure never change deterministic gameplay hash")
    t.that(not service.flush(), "Failed sink remains contained at flush boundary")

func _test_battle_scene_finalization_smoke() -> void:
    var telemetry_directory := OS.get_temp_dir().path_join("meme_fighter_a4_scene_telemetry")
    var replay_directory := OS.get_temp_dir().path_join("meme_fighter_a4_scene_replays")
    var service := TelemetryService.new()
    service.configure("installation-test", "session-scene", telemetry_directory, 64, "build", "content", "test")
    var battle := _battle()
    var recorder := ReplayRecorder.new()
    recorder.begin_recording(&"versus", battle.fighter_a.data.id, battle.fighter_b.data.id)
    battle.set_replay_recorder(recorder)
    battle.simulate_frame(InputFrame.neutral(1), InputFrame.neutral(1))
    service.begin_match("generic_fighter", "zone_fighter", "local_2p", "replay-scene", 0, "match-scene")

    var scene := BattleScene.new()
    scene.telemetry_service = service
    scene.simulation = battle
    scene.replay_recorder = recorder
    scene.replay_id = "replay-scene"
    scene.replay_directory = replay_directory
    scene._match_finalized = false
    scene._finalize_match("reset")
    service.flush_blocking(999)
    var replay_path := replay_directory.path_join("replay-scene%s" % ReplayFormat.FILE_EXTENSION)
    t.that(FileAccess.file_exists(replay_path), "BattleScene finalization saves the correlated replay")
    var file := FileAccess.open(service.output_path(), FileAccess.READ)
    var found_summary := false
    while file != null and file.get_position() < file.get_length():
        var parsed: Variant = JSON.parse_string(file.get_line())
        if typeof(parsed) == TYPE_DICTIONARY and parsed.get("event_name", "") == "match.completed":
            found_summary = parsed.get("payload", {}).get("replay_saved", false)
    if file != null:
        file.close()
    t.that(found_summary, "BattleScene finalization writes replay-correlated match summary")
    var telemetry_path := service.output_path()
    scene.free()
    service.free()
    if FileAccess.file_exists(replay_path):
        DirAccess.remove_absolute(replay_path)
    if FileAccess.file_exists(telemetry_path):
        DirAccess.remove_absolute(telemetry_path)
    DirAccess.remove_absolute(replay_directory)
    DirAccess.remove_absolute(telemetry_directory)
