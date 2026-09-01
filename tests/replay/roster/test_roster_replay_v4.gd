class_name RosterReplayV4Tests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    t.equal(ReplayFormat.SCHEMA_VERSION, 1, "Replay schema stays v1")
    t.equal(ReplayFormat.COMBAT_RULES_VERSION, 5, "Roster gameplay bumps rules compatibility to v5")
    var replay := ReplayData.new()
    t.equal(replay.frames.size(), 0, "ReplayData starts as an input-frame stream")
    t.equal(replay.replay_schema_version, 1, "ReplayData carries schema version only, not snapshot schema")
    print("\nRoster Replay v4 tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
