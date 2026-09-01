extends SceneTree

const CONTRACT_SUITE := preload("res://tests/characters/roster/test_phase6e_goblin_ok_contract.gd")
const GOBLIN_SUITE := preload("res://tests/characters/roster/test_goblin_love.gd")
const OK_SUITE := preload("res://tests/characters/roster/test_ok_meow_boss.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := CONTRACT_SUITE.new().run_all() + GOBLIN_SUITE.new().run_all() + OK_SUITE.new().run_all()
    print("\nPhase 6E Goblin/OK targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(failures)
