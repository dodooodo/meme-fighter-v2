extends SceneTree

const PHASE5_SUITE := preload("res://tests/characters/roster/test_phase5_pink_doge_contract.gd")
const PINK_SUITE := preload("res://tests/characters/roster/test_pink_star.gd")
const DOGE_SUITE := preload("res://tests/characters/roster/test_doge.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += PHASE5_SUITE.new().run_all()
    failures += PINK_SUITE.new().run_all()
    failures += DOGE_SUITE.new().run_all()
    print("\nPhase 5 Pink/Doge targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
