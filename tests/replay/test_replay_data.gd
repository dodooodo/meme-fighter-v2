# Responsibility: M6 ReplayData metadata, frame purity/order, exact normalized InputFrame scalar preservation.
class_name ReplayDataTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_metadata_and_exact_input_fields()
    _test_invalid_gap_duplicate_and_mask()
    print("\nM6 ReplayData tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_metadata_and_exact_input_fields() -> void:
    var replay := ReplayData.new()
    replay.match_rules_id = &"versus"
    replay.stage_id = ReplayFormat.DEFAULT_STAGE_ID
    replay.p1_character_id = &"zone_fighter"
    replay.p2_character_id = &"rush_grappler"
    replay.random_seed = 0
    replay.initial_simulation_frame = 99
    var p1_100 := InputFrame.new(100, -1, -1, InputFrame.InputButton.LIGHT | InputFrame.InputButton.GUARD, InputFrame.InputButton.LIGHT, InputFrame.InputButton.SPECIAL)
    var p2_100 := InputFrame.new(100, 1, 0, InputFrame.InputButton.HEAVY, InputFrame.InputButton.HEAVY, 0)
    var p1_101 := InputFrame.new(101, 0, 0, 0, 0, InputFrame.InputButton.LIGHT | InputFrame.InputButton.GUARD)
    var p2_101 := InputFrame.neutral(101)
    replay.frames.append(ReplayFramePair.new(100, p1_100, p2_100))
    replay.frames.append(ReplayFramePair.new(101, p1_101, p2_101))
    replay.expected_final_state_hash = "abc123"
    t.equal(replay.replay_schema_version, ReplayFormat.SCHEMA_VERSION, "ReplayData uses centralized schema version")
    t.equal(replay.combat_rules_version, ReplayFormat.COMBAT_RULES_VERSION, "ReplayData uses centralized combat rules version")
    t.equal(replay.match_rules_id, &"versus", "Replay metadata stores MatchRules stable ID")
    t.equal(replay.stage_id, &"greybox_stage", "Replay metadata stores stable prototype stage ID")
    t.equal(replay.p1_character_id, &"zone_fighter", "Replay metadata stores P1 CharacterData ID")
    t.equal(replay.p2_character_id, &"rush_grappler", "Replay metadata stores P2 CharacterData ID")
    t.equal(replay.frame_count(), 2, "Replay frame_count derives from complete frame pair array")
    t.equal(replay.final_frame_number(), 101, "Replay final frame derives from final pair")
    t.that(replay.is_structurally_valid(), "ReplayData validates contiguous complete normalized frames")
    var copied := replay.get_frame_pair(100)
    t.equal(copied.p1_input.direction_x, -1, "Replay preserves direction_x exactly")
    t.equal(copied.p1_input.direction_y, -1, "Replay preserves direction_y exactly")
    t.equal(copied.p1_input.held_bits, InputFrame.InputButton.LIGHT | InputFrame.InputButton.GUARD, "Replay preserves held bits exactly")
    t.equal(copied.p1_input.pressed_bits, InputFrame.InputButton.LIGHT, "Replay preserves pressed bits exactly")
    t.equal(copied.p1_input.released_bits, InputFrame.InputButton.SPECIAL, "Replay preserves released bits exactly")

func _test_invalid_gap_duplicate_and_mask() -> void:
    var replay := ReplayData.new()
    replay.match_rules_id = &"versus"
    replay.p1_character_id = &"generic_fighter"
    replay.p2_character_id = &"rush_grappler"
    replay.expected_final_state_hash = "hash"
    replay.frames.clear()
    replay.frames.append(ReplayFramePair.new(1, InputFrame.neutral(1), InputFrame.neutral(1)))
    replay.frames.append(ReplayFramePair.new(3, InputFrame.neutral(3), InputFrame.neutral(3)))
    t.that(not replay.is_structurally_valid(), "Replay frame gap is invalid instead of auto-filled neutral")
    replay.frames.clear()
    replay.frames.append(ReplayFramePair.new(1, InputFrame.neutral(1), InputFrame.neutral(1)))
    replay.frames.append(ReplayFramePair.new(1, InputFrame.neutral(1), InputFrame.neutral(1)))
    t.that(not replay.is_structurally_valid(), "Duplicate replay frame is invalid")
    replay.frames.clear()
    replay.frames.append(ReplayFramePair.new(1, InputFrame.new(1, 0, 0, 1 << 20, 0, 0), InputFrame.neutral(1)))
    t.that(not replay.is_structurally_valid(), "Replay rejects action bits outside the five canonical InputButtons")
