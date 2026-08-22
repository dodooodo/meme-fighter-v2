# Responsibility: A-DATA-006 bounded performance sampling and error sanitization tests.
class_name PerformanceTelemetryTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_fps_memory_and_long_frame_sampling()
    _test_load_and_error_records()
    print("\nA-DATA performance tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _names(records: Array[Dictionary]) -> Array[String]:
    var out: Array[String] = []
    for record in records:
        out.append(str(record.get("event_name", "")))
    return out

func _test_fps_memory_and_long_frame_sampling() -> void:
    var sampler := TelemetryPerformanceSampler.new(3, 2)
    var records: Array[Dictionary] = []
    records.append_array(sampler.sample_frame(0.050, 20.0, 1000))
    records.append_array(sampler.sample_frame(0.016, 45.0, 1200))
    records.append_array(sampler.sample_frame(0.016, 60.0, 1400))
    var names := _names(records)
    t.that(names.has("performance.long_frame"), "Long frame emits a bounded event")
    t.that(names.has("performance.fps_snapshot"), "Sampling interval emits FPS buckets")
    t.that(names.has("performance.memory_snapshot"), "Sampling interval emits memory snapshot")
    var snapshot: Dictionary = {}
    for record in records:
        if record.get("event_name", "") == "performance.fps_snapshot":
            snapshot = record.get("payload", {})
    t.equal(snapshot.get("fps_buckets", {}).get("under_30", 0), 1, "FPS histogram counts under-30 sample")
    t.equal(snapshot.get("fps_buckets", {}).get("30_to_49", 0), 1, "FPS histogram counts 30-49 sample")
    t.equal(snapshot.get("fps_buckets", {}).get("60_plus", 0), 1, "FPS histogram counts 60+ sample")

func _test_load_and_error_records() -> void:
    var sampler := TelemetryPerformanceSampler.new()
    t.equal(sampler.load_duration(-1.0).size(), 0, "Negative load duration is rejected")
    t.equal(sampler.load_duration(12.5).get("event_name", ""), "performance.load_duration", "Load duration has stable event name")
    t.equal(sampler.asset_pack_load_duration(8.0).get("event_name", ""), "performance.asset_pack_load_duration", "Asset load duration has stable event name")
    var error := sampler.error("CONFIG_FAILED", "x".repeat(400), true)
    var payload: Dictionary = error.get("payload", {})
    t.equal(error.get("event_name", ""), "performance.error", "Crash/error marker has stable event name")
    t.that(str(payload.get("message", "")).length() <= 256, "Error messages are length-bounded")
    t.equal(payload.get("fatal", false), true, "Fatal marker is explicit")
