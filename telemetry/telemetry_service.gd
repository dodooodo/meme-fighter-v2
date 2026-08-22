# Responsibility: Application-side telemetry composition, envelope creation and bounded local flushing.
# Owns: one app session identity, match aggregator, performance sampler and local sink orchestration.
# Does NOT own: gameplay decisions, simulation state, replay frames, HTTP, analytics storage, UI.
# Dependencies: telemetry components and read-only CombatEvent/BattleSimulation inputs.
class_name TelemetryService
extends Node

var identity: TelemetryIdentity = TelemetryIdentity.new()
var sink: LocalTelemetrySink = LocalTelemetrySink.new()
var match_aggregator: TelemetryMatchAggregator = TelemetryMatchAggregator.new()
var performance_sampler: TelemetryPerformanceSampler = TelemetryPerformanceSampler.new()
var build_id: String = ""
var content_version: String = ""
var platform: String = ""
var user_id: String = ""
var _configured: bool = false
var _current_replay_id: String = ""

func configure(
    installation_id: String = "",
    session_id: String = "",
    sink_directory: String = LocalTelemetrySink.DEFAULT_DIRECTORY,
    max_buffer: int = LocalTelemetrySink.DEFAULT_MAX_BUFFER,
    p_build_id: String = "",
    p_content_version: String = "",
    p_platform: String = ""
) -> bool:
    if not identity.configure(installation_id, session_id):
        return false
    build_id = p_build_id if not p_build_id.is_empty() else str(ProjectSettings.get_setting("application/config/version", "development"))
    content_version = p_content_version if not p_content_version.is_empty() else str(ProjectSettings.get_setting("telemetry/content_version", "stage-a-v1"))
    platform = p_platform if not p_platform.is_empty() else OS.get_name().to_lower().replace(" ", "_")
    _configured = not build_id.is_empty() and not content_version.is_empty() and not platform.is_empty()
    var sink_ready := sink.configure(identity.session_id, sink_directory, max_buffer)
    return _configured and sink_ready

func ensure_configured() -> bool:
    if _configured:
        return not sink.output_path().is_empty()
    return configure()

func begin_match(
    p1_character_id: String,
    p2_character_id: String,
    mode: String,
    replay_id: String,
    initial_frame: int = 0,
    match_id_override: String = ""
) -> String:
    if not _configured:
        ensure_configured()
    var match_id := identity.begin_match(match_id_override)
    _current_replay_id = replay_id if not replay_id.is_empty() else "replay-%s" % match_id
    if not match_aggregator.begin_match(p1_character_id, p2_character_id, mode, _current_replay_id, initial_frame, build_id, content_version):
        identity.finish_match()
        _current_replay_id = ""
        return ""
    return match_id

func observe_combat_events(events: Array[CombatEvent], simulation: BattleSimulation) -> void:
    if not _configured or not match_aggregator.is_active():
        return
    for event in events:
        if event != null and event.type == CombatEvent.EventType.ROUND_STARTED:
            identity.begin_round(event.round_number)
    _emit_records(match_aggregator.observe(events, simulation))

func end_match(disconnect_reason: String, simulation: BattleSimulation, replay: Dictionary) -> void:
    if not _configured or not match_aggregator.is_active():
        return
    identity.finish_round()
    _emit_records(match_aggregator.complete(simulation, disconnect_reason, replay))
    identity.finish_match()
    _current_replay_id = ""

func sample_performance(delta_seconds: float, fps: float, memory_bytes: int) -> void:
    if _configured:
        _emit_records(performance_sampler.sample_frame(delta_seconds, fps, memory_bytes))

func record_load_duration(duration_ms: float) -> void:
    _emit_record(performance_sampler.load_duration(duration_ms))

func record_asset_pack_load_duration(duration_ms: float) -> void:
    _emit_record(performance_sampler.asset_pack_load_duration(duration_ms))

func record_error(code: String, message: String, fatal: bool = false) -> void:
    _emit_record(performance_sampler.error(code, message, fatal))

func flush(max_events: int = 64) -> bool:
    return sink.flush(max_events)

func flush_blocking(max_events: int = 64) -> bool:
    return sink.flush_blocking(max_events)

func output_path() -> String:
    return sink.output_path()

func current_replay_id() -> String:
    return _current_replay_id

func pending_events() -> Array[Dictionary]:
    return sink.pending_events()

func _exit_tree() -> void:
    if _configured:
        sink.flush_blocking(256)

func _emit_records(records: Array[Dictionary]) -> void:
    for record in records:
        _emit_record(record)

func _emit_record(record: Dictionary) -> void:
    if not _configured or record.is_empty():
        return
    var event_name := str(record.get("event_name", ""))
    var payload: Variant = record.get("payload", {})
    if typeof(payload) != TYPE_DICTIONARY:
        return
    var envelope := TelemetryEnvelopeV1.create(
        event_name,
        payload,
        identity,
        _utc_now(),
        build_id,
        content_version,
        platform,
        user_id
    )
    if not envelope.is_empty():
        sink.enqueue(envelope)

func _utc_now() -> String:
    return Time.get_datetime_string_from_system(true, false) + "Z"
