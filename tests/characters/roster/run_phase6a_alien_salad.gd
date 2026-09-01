extends SceneTree

const PHASE6A_SUITE := preload("res://tests/characters/roster/test_phase6a_alien_salad_contract.gd")
const ALIEN_SUITE := preload("res://tests/characters/roster/test_alien_meow.gd")
const SALAD_SUITE := preload("res://tests/characters/roster/test_salad_cat.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += PHASE6A_SUITE.new().run_all()
    failures += ALIEN_SUITE.new().run_all()
    failures += SALAD_SUITE.new().run_all()
    print("\nPhase 6A Alien/Salad targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
