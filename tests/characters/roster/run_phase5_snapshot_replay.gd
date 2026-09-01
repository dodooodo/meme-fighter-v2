extends SceneTree

const GATE2_SNAPSHOT := preload("res://tests/snapshot/test_gate2_snapshot_scenarios.gd")
const ROSTER_MECHANICS := preload("res://tests/mechanics/test_roster_generic_mechanics.gd")
const ROSTER_SNAPSHOT := preload("res://tests/snapshot/roster/test_roster_snapshot_v8.gd")
const ROSTER_REPLAY := preload("res://tests/replay/roster/test_roster_replay_v4.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += GATE2_SNAPSHOT.new().run_all()
    failures += ROSTER_MECHANICS.new().run_all()
    failures += ROSTER_SNAPSHOT.new().run_all()
    failures += ROSTER_REPLAY.new().run_all()
    print("\nPhase 5 Snapshot/Replay regression: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
