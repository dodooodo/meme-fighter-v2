extends SceneTree

const PHASE6B_SUITE := preload("res://tests/characters/roster/test_phase6b_ya_sauce_contract.gd")
const YA_SUITE := preload("res://tests/characters/roster/test_ya_mouse.gd")
const SAUCE_SUITE := preload("res://tests/characters/roster/test_sauce_stubble_dog.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += PHASE6B_SUITE.new().run_all()
    failures += YA_SUITE.new().run_all()
    failures += SAUCE_SUITE.new().run_all()
    print("\nPhase 6B YA/Sauce targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
