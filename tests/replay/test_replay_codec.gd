# Responsibility: M6 explicit JSON replay codec roundtrip, FileAccess boundary and corruption rejection.
class_name ReplayCodecTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_codec_roundtrip()
    _test_corruption_rejection()
    _test_file_roundtrip()
    print("\nM6 Replay Codec tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _sample() -> ReplayData:
    var replay := ReplayData.new()
    replay.match_rules_id = &"versus"
    replay.stage_id = ReplayFormat.DEFAULT_STAGE_ID
    replay.p1_character_id = &"zone_fighter"
    replay.p2_character_id = &"rush_grappler"
    replay.initial_simulation_frame = 0
    replay.frames.append(ReplayFramePair.new(1, InputFrame.with_special_press(1), InputFrame.neutral(1)))
    replay.frames.append(ReplayFramePair.new(2, InputFrame.new(2, -1, 1, InputFrame.InputButton.GUARD, 0, InputFrame.InputButton.SPECIAL), InputFrame.with_light_press(2)))
    replay.expected_final_state_hash = "0123456789abcdef"
    return replay

func _test_codec_roundtrip() -> void:
    var replay := _sample()
    var encoded := ReplayCodec.encode_to_string(replay)
    t.that(not encoded.is_empty(), "ReplayCodec emits explicit JSON for valid ReplayData")
    var decoded := ReplayCodec.decode_from_string(encoded)
    t.that(decoded != null, "ReplayCodec decodes its explicit JSON representation")
    t.equal(decoded.replay_schema_version, ReplayFormat.SCHEMA_VERSION, "Codec preserves replay schema version")
    t.equal(decoded.combat_rules_version, ReplayFormat.COMBAT_RULES_VERSION, "Codec preserves combat rules version")
    t.equal(decoded.match_rules_id, replay.match_rules_id, "Codec preserves MatchRules ID")
    t.equal(decoded.stage_id, replay.stage_id, "Codec preserves stage ID")
    t.equal(decoded.p1_character_id, replay.p1_character_id, "Codec preserves P1 Character ID")
    t.equal(decoded.p2_character_id, replay.p2_character_id, "Codec preserves P2 Character ID")
    t.equal(decoded.frames.size(), 2, "Codec preserves every replay frame pair")
    t.equal(decoded.frames[1].p1_input.direction_x, -1, "Codec preserves normalized direction")
    t.equal(decoded.frames[1].p1_input.released_bits, InputFrame.InputButton.SPECIAL, "Codec preserves released bitset")
    t.equal(decoded.expected_final_state_hash, replay.expected_final_state_hash, "Codec preserves final gameplay hash as String")

func _test_corruption_rejection() -> void:
    var base: Dictionary = JSON.parse_string(ReplayCodec.encode_to_string(_sample()))
    var bad_schema := base.duplicate(true)
    bad_schema["replay_schema_version"] = 999
    t.equal(ReplayCodec.decode_from_string(JSON.stringify(bad_schema)), null, "Codec rejects wrong replay schema")
    var bad_combat := base.duplicate(true)
    bad_combat["combat_rules_version"] = 999
    t.equal(ReplayCodec.decode_from_string(JSON.stringify(bad_combat)), null, "Codec rejects wrong combat rules version")
    var bad_stage := base.duplicate(true)
    bad_stage["stage_id"] = "other_stage"
    t.equal(ReplayCodec.decode_from_string(JSON.stringify(bad_stage)), null, "Codec rejects unknown stage ID")
    var gap := base.duplicate(true)
    gap["frames"][1]["frame_number"] = 3
    gap["frames"][1]["p1"]["frame_number"] = 3
    gap["frames"][1]["p2"]["frame_number"] = 3
    t.equal(ReplayCodec.decode_from_string(JSON.stringify(gap)), null, "Codec rejects replay frame gap/out-of-order sequence")
    var bad_dir := base.duplicate(true)
    bad_dir["frames"][0]["p1"]["direction_x"] = 2
    t.equal(ReplayCodec.decode_from_string(JSON.stringify(bad_dir)), null, "Codec rejects direction outside {-1,0,+1}")
    var bad_bits := base.duplicate(true)
    bad_bits["frames"][0]["p1"]["held_bits"] = 1048576
    t.equal(ReplayCodec.decode_from_string(JSON.stringify(bad_bits)), null, "Codec rejects bit fields outside canonical InputButton mask")

func _test_file_roundtrip() -> void:
    # Use the OS temporary directory so restricted CI/local runners do not
    # depend on an OS-specific user-data location. ReplayCodec still receives a
    # normal FileAccess path and removes the fixture after the roundtrip.
    var path := OS.get_temp_dir().path_join("m6_replay_codec_test.tbf_replay.json")
    var replay := _sample()
    t.that(ReplayCodec.save_to_file(path, replay), "ReplayCodec save_to_file uses FileAccess only at persistence boundary")
    var loaded := ReplayCodec.load_from_file(path)
    t.that(loaded != null and loaded.expected_final_state_hash == replay.expected_final_state_hash, "ReplayCodec load_from_file roundtrips explicit fields")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
