# Focused A4 telemetry runner.
extends SceneTree

const IDENTITY_ENVELOPE := preload("res://tests/telemetry/test_telemetry_identity_envelope.gd")
const LOCAL_SINK := preload("res://tests/telemetry/test_local_telemetry_sink.gd")
const MATCH_AGGREGATOR := preload("res://tests/telemetry/test_match_telemetry_aggregator.gd")
const PERFORMANCE := preload("res://tests/telemetry/test_performance_telemetry.gd")
const SERVICE_INTEGRATION := preload("res://tests/telemetry/test_telemetry_service_integration.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    failures += IDENTITY_ENVELOPE.new().run_all()
    failures += LOCAL_SINK.new().run_all()
    failures += MATCH_AGGREGATOR.new().run_all()
    failures += PERFORMANCE.new().run_all()
    failures += SERVICE_INTEGRATION.new().run_all()
    quit(failures)
