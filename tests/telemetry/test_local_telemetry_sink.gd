# Responsibility: A-DATA-007 bounded JSONL persistence and failure containment tests.
class_name LocalTelemetrySinkTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_bounded_jsonl_append()
    _test_invalid_event_and_sink_failure_are_contained()
    print("\nA-DATA local sink tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _event(index: int) -> Dictionary:
    var identity := TelemetryIdentity.new()
    identity.configure("installation-test", "session-test")
    return TelemetryEnvelopeV1.create(
        "performance.error",
        {"code": "E%d" % index},
        identity,
        "2026-08-23T01:02:%02dZ" % index,
        "build-test",
        "content-test",
        "test"
    )

func _test_bounded_jsonl_append() -> void:
    var directory := OS.get_temp_dir().path_join("meme_fighter_a4_sink")
    var sink := LocalTelemetrySink.new()
    t.that(sink.configure("session-test", directory, 2), "Local sink creates a session-scoped JSONL target")
    t.that(sink.enqueue(_event(1)), "Sink accepts valid event one")
    t.that(sink.enqueue(_event(2)), "Sink accepts valid event two")
    t.that(sink.enqueue(_event(3)), "Sink remains non-blocking when buffer is full")
    t.equal(sink.pending_count(), 2, "Sink buffer stays bounded")
    t.equal(sink.dropped_count(), 1, "Sink reports oldest-event overflow")
    t.that(sink.flush(1), "Sink dispatches a bounded batch without waiting for disk")
    t.equal(sink.pending_count(), 2, "In-flight event remains accounted for until background write completes")
    t.that(sink.wait_for_idle(), "Sink can join its writer at an explicit lifecycle boundary")
    t.equal(sink.pending_count(), 1, "Completed background batch removes only written event")
    t.that(sink.flush_blocking(10), "Explicit shutdown flush appends the remaining batch")

    var file := FileAccess.open(sink.output_path(), FileAccess.READ)
    var lines: Array[String] = []
    while file != null and file.get_position() < file.get_length():
        var line := file.get_line()
        if not line.is_empty():
            lines.append(line)
    if file != null:
        file.close()
    t.equal(lines.size(), 2, "JSONL contains one object per retained event")
    for line in lines:
        var parsed: Variant = JSON.parse_string(line)
        t.that(typeof(parsed) == TYPE_DICTIONARY and TelemetryEnvelopeV1.is_valid(parsed), "Every JSONL line is a valid envelope")
    if FileAccess.file_exists(sink.output_path()):
        DirAccess.remove_absolute(sink.output_path())
    DirAccess.remove_absolute(directory)

func _test_invalid_event_and_sink_failure_are_contained() -> void:
    var sink := LocalTelemetrySink.new()
    t.that(not sink.configure("session-test", "res://project.godot", 4), "Sink reports an unusable directory without throwing")
    t.that(not sink.enqueue({"event_name": "broken"}), "Sink rejects invalid envelopes")
    t.that(not sink.flush(), "Unconfigured sink flush fails closed")
