extends SceneTree

const CONTRACT_SUITE := preload("res://tests/characters/roster/test_phase6d_scared_cat_contract.gd")
const SCARED_SUITE := preload("res://tests/characters/roster/test_scared_cat.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := CONTRACT_SUITE.new().run_all() + SCARED_SUITE.new().run_all()
    print("\nPhase 6D Scared Cat targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(failures)
