# Phase 7 harness probe: intentionally emits a Godot Invalid call for scanner verification.
extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    create_timer(0.05).timeout.connect(quit)
    var absent: Variant = null
    absent.intentional_runtime_error_probe()
