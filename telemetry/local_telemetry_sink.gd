# Responsibility: Bounded, batched, asynchronous local Telemetry Envelope v1 JSONL persistence.
# Owns: in-memory queue, one background writer, drop count, session file path and append boundary.
# Does NOT own: event creation, gameplay state, replay payloads, HTTP, retry across app sessions.
# Dependencies: TelemetryEnvelopeV1 and FileAccess/DirAccess only.
class_name LocalTelemetrySink
extends RefCounted

const DEFAULT_DIRECTORY: String = "user://telemetry"
const DEFAULT_MAX_BUFFER: int = 512

var _output_path: String = ""
var _max_buffer: int = DEFAULT_MAX_BUFFER
var _buffer: Array[Dictionary] = []
var _dropped_count: int = 0
var _configured: bool = false
var _write_thread: Thread = Thread.new()
var _in_flight_count: int = 0

func configure(session_id: String, directory: String = DEFAULT_DIRECTORY, max_buffer: int = DEFAULT_MAX_BUFFER) -> bool:
    if _in_flight_count > 0 and not wait_for_idle():
        return false
    _configured = false
    _output_path = ""
    _buffer.clear()
    _dropped_count = 0
    if session_id.strip_edges().is_empty() or directory.strip_edges().is_empty() or max_buffer < 1:
        return false
    var absolute_directory := ProjectSettings.globalize_path(directory)
    if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
        return false
    if not DirAccess.dir_exists_absolute(absolute_directory):
        return false
    _max_buffer = max_buffer
    _output_path = directory.path_join("telemetry-%s.jsonl" % _safe_segment(session_id))
    _configured = true
    return true

func enqueue(event: Dictionary) -> bool:
    if not _configured or not TelemetryEnvelopeV1.is_valid(event):
        return false
    if _buffer.size() >= _max_buffer:
        _dropped_count += 1
        if _buffer.size() <= _in_flight_count:
            return true
        _buffer.remove_at(_in_flight_count)
    _buffer.append(event.duplicate(true))
    return true

func flush(max_events: int = 64) -> bool:
    if not _configured:
        return false
    if not _harvest_finished_write(false):
        return false
    if _in_flight_count > 0 or _buffer.is_empty() or max_events <= 0:
        return true
    var count := mini(max_events, _buffer.size())
    var batch: Array[Dictionary] = []
    for index in range(count):
        batch.append(_buffer[index].duplicate(true))
    _in_flight_count = count
    var start_error := _write_thread.start(_write_batch.bind(_output_path, batch))
    if start_error != OK:
        _in_flight_count = 0
        _write_thread = Thread.new()
        return false
    return true

func wait_for_idle() -> bool:
    return _harvest_finished_write(true)

func flush_blocking(max_events: int = 64) -> bool:
    if not _configured:
        return false
    while not _buffer.is_empty():
        if not flush(max_events) or not wait_for_idle():
            return false
    return true

func _harvest_finished_write(wait: bool) -> bool:
    if _in_flight_count <= 0:
        return true
    if _write_thread.is_alive() and not wait:
        return true
    var succeeded: Variant = _write_thread.wait_to_finish()
    _write_thread = Thread.new()
    if succeeded != true:
        _in_flight_count = 0
        return false
    for _index in range(_in_flight_count):
        _buffer.pop_front()
    _in_flight_count = 0
    return true

static func _write_batch(path: String, batch: Array[Dictionary]) -> bool:
    var file: FileAccess
    if FileAccess.file_exists(path):
        file = FileAccess.open(path, FileAccess.READ_WRITE)
        if file != null:
            file.seek_end()
    else:
        file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    for event in batch:
        file.store_line(JSON.stringify(event))
        if file.get_error() != OK:
            file.close()
            return false
    file.close()
    return true

func pending_count() -> int:
    return _buffer.size()

func dropped_count() -> int:
    return _dropped_count

func output_path() -> String:
    return _output_path

func pending_events() -> Array[Dictionary]:
    return _buffer.duplicate(true)

static func _safe_segment(value: String) -> String:
    var result := ""
    for character in value:
        if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789-_":
            result += character
    return result if not result.is_empty() else "session"
