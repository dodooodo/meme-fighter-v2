extends SceneTree

const CONTRACT_SUITE := preload("res://tests/characters/roster/test_phase6c_penguin_magic_contract.gd")
const PENGUIN_SUITE := preload("res://tests/characters/roster/test_tempura_penguin.gd")
const MAGIC_SUITE := preload("res://tests/characters/roster/test_magic_orange_cat.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += CONTRACT_SUITE.new().run_all()
    failures += PENGUIN_SUITE.new().run_all()
    failures += MAGIC_SUITE.new().run_all()
    print("\nPhase 6C Penguin/Magic targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(failures)
