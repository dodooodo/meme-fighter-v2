# Responsibility: Sparse bounded render/service-side performance event derivation.
# Owns: FPS histogram interval, long-frame cooldown, memory/load/error payload bounds.
# Does NOT own: simulation time, profiler traces, crash interception, transport, gameplay decisions.
# Dependencies: none.
class_name TelemetryPerformanceSampler
extends RefCounted

const LONG_FRAME_MS: float = 33.333
const MAX_ERROR_MESSAGE_LENGTH: int = 256

var _report_interval_frames: int = 300
var _long_frame_cooldown: int = 60
var _sample_index: int = 0
var _last_long_frame_index: int = -60
var _fps_buckets: Dictionary = {}
var _latest_memory_bytes: int = 0

func _init(report_interval_frames: int = 300, long_frame_cooldown: int = 60) -> void:
    _report_interval_frames = maxi(1, report_interval_frames)
    _long_frame_cooldown = maxi(1, long_frame_cooldown)
    _last_long_frame_index = -_long_frame_cooldown
    _reset_buckets()

func sample_frame(delta_seconds: float, fps: float, memory_bytes: int) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if delta_seconds <= 0.0 or is_nan(delta_seconds) or is_inf(delta_seconds):
        return records
    _sample_index += 1
    _latest_memory_bytes = maxi(0, memory_bytes)
    var delta_ms := minf(delta_seconds * 1000.0, 60000.0)
    if delta_ms >= LONG_FRAME_MS and _sample_index - _last_long_frame_index >= _long_frame_cooldown:
        records.append(_record("performance.long_frame", {"duration_ms": delta_ms}))
        _last_long_frame_index = _sample_index
    var bucket := _fps_bucket(maxf(0.0, fps))
    _fps_buckets[bucket] = int(_fps_buckets[bucket]) + 1
    if _sample_index % _report_interval_frames == 0:
        records.append(_record("performance.fps_snapshot", {
            "sample_count": _report_interval_frames,
            "fps_buckets": _fps_buckets.duplicate(true),
        }))
        records.append(_record("performance.memory_snapshot", {"memory_bytes": _latest_memory_bytes}))
        _reset_buckets()
    return records

func load_duration(duration_ms: float) -> Dictionary:
    return _duration_record("performance.load_duration", duration_ms)

func asset_pack_load_duration(duration_ms: float) -> Dictionary:
    return _duration_record("performance.asset_pack_load_duration", duration_ms)

func error(code: String, message: String, fatal: bool = false) -> Dictionary:
    var safe_code := code.strip_edges().to_upper().substr(0, 64)
    if safe_code.is_empty():
        return {}
    var safe_message := message.replace("\n", " ").replace("\r", " ").substr(0, MAX_ERROR_MESSAGE_LENGTH)
    return _record("performance.error", {"code": safe_code, "message": safe_message, "fatal": fatal})

func _duration_record(event_name: String, duration_ms: float) -> Dictionary:
    if duration_ms < 0.0 or is_nan(duration_ms) or is_inf(duration_ms):
        return {}
    return _record(event_name, {"duration_ms": minf(duration_ms, 3600000.0)})

func _record(event_name: String, payload: Dictionary) -> Dictionary:
    return {"event_name": event_name, "payload": payload}

func _fps_bucket(fps: float) -> String:
    if fps < 30.0:
        return "under_30"
    if fps < 50.0:
        return "30_to_49"
    if fps < 60.0:
        return "50_to_59"
    return "60_plus"

func _reset_buckets() -> void:
    _fps_buckets = {"under_30": 0, "30_to_49": 0, "50_to_59": 0, "60_plus": 0}
