extends SceneTree
const CONTRACT_SUITE := preload("res://tests/characters/roster/test_phase6g_bao_contract.gd")
const BAO_SUITE := preload("res://tests/characters/roster/test_bao_la.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
    var failures := CONTRACT_SUITE.new().run_all() + BAO_SUITE.new().run_all()
    print("\nPhase 6G Bao targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(failures)
