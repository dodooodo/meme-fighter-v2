extends SceneTree

const CONTRACT_SUITE := preload("res://tests/characters/roster/test_phase6f_blade_niu_contract.gd")
const BLADE_SUITE := preload("res://tests/characters/roster/test_blade_shield.gd")
const NIU_SUITE := preload("res://tests/characters/roster/test_niu_lai.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := CONTRACT_SUITE.new().run_all() + BLADE_SUITE.new().run_all() + NIU_SUITE.new().run_all()
    print("\nPhase 6F Blade/Niu targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(failures)
