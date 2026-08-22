class_name RosterSnapshotV8Tests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var bao := RosterRegistry.character_by_id(&"bao_la")
    var battle := BattleSimulation.new()
    battle.configure(bao, RosterRegistry.character_by_id(&"magic_orange_cat"))
    battle.fighter_a.resources.set_value(&"resolve", 2)
    battle.fighter_a.mode.enter(&"last_stand", 91, 7)
    battle.fighter_a.sync_mechanics_from_mode()
    var snap := battle.capture_state()
    t.equal(snap.version, 8, "Roster snapshot version is v8")
    var signature := battle.state_signature()
    t.that(battle.restore_state(snap), "v8 snapshot restores roster mechanics")
    t.equal(battle.state_signature(), signature, "v8 restore reproduces canonical hash")
    print("\nRoster Snapshot v8 tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
