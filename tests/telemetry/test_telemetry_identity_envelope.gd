# Responsibility: A-DATA-001/002 identity persistence and Event Envelope v1 contract tests.
class_name TelemetryIdentityEnvelopeTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_identity_lifecycle_and_persistence()
    _test_envelope_contract_and_json_roundtrip()
    _test_envelope_rejects_invalid_or_private_payloads()
    print("\nA-DATA identity/envelope tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_identity_lifecycle_and_persistence() -> void:
    var path := OS.get_temp_dir().path_join("meme_fighter_a4_installation_id.txt")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
    var first := TelemetryIdentity.load_or_create_installation_id(path)
    var second := TelemetryIdentity.load_or_create_installation_id(path)
    t.that(not first.is_empty(), "First-run installation ID is created")
    t.equal(second, first, "Installation ID persists across loads")

    var identity := TelemetryIdentity.new()
    t.that(identity.configure("installation-test", "session-test"), "Identity accepts explicit test installation/session IDs")
    t.equal(identity.begin_match("match-test"), "match-test", "Match lifecycle exposes stable match ID")
    t.equal(identity.begin_round(2, "round-test"), "round-test", "Round lifecycle exposes stable round ID")
    t.equal(identity.next_event_id(), "session-test-event-00000001", "Event IDs are monotonic within a session")
    t.equal(identity.next_event_id(), "session-test-event-00000002", "Event IDs remain unique")
    DirAccess.remove_absolute(path)

func _test_envelope_contract_and_json_roundtrip() -> void:
    var identity := TelemetryIdentity.new()
    identity.configure("installation-test", "session-test")
    identity.begin_match("match-test")
    identity.begin_round(1, "round-test")
    var envelope := TelemetryEnvelopeV1.create(
        "move.summary",
        {"move_id": "stand_light", "use_count": 2},
        identity,
        "2026-08-23T01:02:03Z",
        "build-test",
        "content-test",
        "macos"
    )
    t.that(TelemetryEnvelopeV1.is_valid(envelope), "Envelope v1 accepts every required scalar context field")
    for key in ["event_name", "event_version", "event_id", "occurred_at", "installation_id", "session_id", "match_id", "round_id", "build_id", "content_version", "platform", "payload"]:
        t.that(envelope.has(key), "Envelope contains %s" % key)
    var decoded: Variant = JSON.parse_string(JSON.stringify(envelope))
    t.that(typeof(decoded) == TYPE_DICTIONARY and TelemetryEnvelopeV1.is_valid(decoded), "Envelope round-trips as strict JSON")

func _test_envelope_rejects_invalid_or_private_payloads() -> void:
    var identity := TelemetryIdentity.new()
    identity.configure("installation-test", "session-test")
    var bad_name := TelemetryEnvelopeV1.create("Move Summary", {}, identity, "2026-08-23T01:02:03Z", "build", "content", "macos")
    t.that(bad_name.is_empty(), "Envelope rejects non-canonical event names")
    var private_payload := TelemetryEnvelopeV1.create("match.completed", {"email": "player@example.com"}, identity, "2026-08-23T01:02:03Z", "build", "content", "macos")
    t.that(private_payload.is_empty(), "Envelope rejects direct-identifier payload keys")
    var object_payload := TelemetryEnvelopeV1.create("match.completed", {"resource": Resource.new()}, identity, "2026-08-23T01:02:03Z", "build", "content", "macos")
    t.that(object_payload.is_empty(), "Envelope rejects non-JSON-safe Object payloads")
    var malformed_time := TelemetryEnvelopeV1.create("match.completed", {}, identity, "today", "build", "content", "macos")
    t.that(malformed_time.is_empty(), "Envelope rejects malformed UTC timestamps")
    var unknown_field := TelemetryEnvelopeV1.create("match.completed", {}, identity, "2026-08-23T01:02:03Z", "build", "content", "macos")
    unknown_field["unexpected"] = true
    t.that(not TelemetryEnvelopeV1.is_valid(unknown_field), "Envelope rejects undeclared top-level fields")
