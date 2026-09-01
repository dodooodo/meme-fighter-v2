extends SceneTree

const READ_FACADE_SUITE := preload("res://tests/gate3/test_fighter_read_facade.gd")
const CPU_SUITE := preload("res://tests/gate3/test_gate3_cpu.gd")
const TRAINING_DEBUG_SUITE := preload("res://tests/gate3/test_gate3_training_debug.gd")
const TELEMETRY_SUITE := preload("res://tests/gate3/test_gate3_telemetry.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += READ_FACADE_SUITE.new().run_all()
    failures += CPU_SUITE.new().run_all()
    failures += TRAINING_DEBUG_SUITE.new().run_all()
    failures += TELEMETRY_SUITE.new().run_all()
    print("\nPhase 3 API drift targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
