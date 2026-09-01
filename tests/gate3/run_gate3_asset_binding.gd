extends SceneTree

const ASSET_BINDING_SUITE := preload("res://tests/gate3/test_gate3_asset_binding.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := ASSET_BINDING_SUITE.new().run_all()
    print("\nGate 3 asset-binding targeted result: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)
