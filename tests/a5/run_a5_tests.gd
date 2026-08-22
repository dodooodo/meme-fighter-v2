extends SceneTree

const DOGE_PACKAGE_SUITE := preload("res://tests/a5/test_doge_package.gd")
const FRONTEND_TRAINING_SUITE := preload("res://tests/a5/test_character_select_and_training.gd")
const TUTORIAL_SUITE := preload("res://tests/a5/test_tutorial_model.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += DOGE_PACKAGE_SUITE.new().run_all()
    failures += FRONTEND_TRAINING_SUITE.new().run_all()
    failures += TUTORIAL_SUITE.new().run_all()
    print("\nA5 focused result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
