# Responsibility: Local pseudonymous telemetry identity lifecycle and persistent installation ID.
# Owns: installation/session/match/round/event IDs and event sequence.
# Does NOT own: account login, platform identities, analytics payloads, transport, gameplay state.
# Dependencies: FileAccess/DirAccess, Time and Crypto only.
class_name TelemetryIdentity
extends RefCounted

const DEFAULT_INSTALLATION_PATH: String = "user://telemetry/installation_id.txt"
static var _process_nonce: int = 0

var installation_id: String = ""
var session_id: String = ""
var match_id: String = ""
var round_id: String = ""
var _event_sequence: int = 0

func configure(p_installation_id: String = "", p_session_id: String = "") -> bool:
    installation_id = p_installation_id.strip_edges()
    if installation_id.is_empty():
        installation_id = load_or_create_installation_id()
    session_id = p_session_id.strip_edges()
    if session_id.is_empty():
        session_id = generate_id("session")
    match_id = ""
    round_id = ""
    _event_sequence = 0
    return not installation_id.is_empty() and not session_id.is_empty()

func begin_match(override_id: String = "") -> String:
    match_id = override_id.strip_edges()
    if match_id.is_empty():
        match_id = generate_id("match")
    round_id = ""
    return match_id

func begin_round(round_number: int, override_id: String = "") -> String:
    if match_id.is_empty() or round_number < 1:
        return ""
    round_id = override_id.strip_edges()
    if round_id.is_empty():
        round_id = "%s-round-%02d" % [match_id, round_number]
    return round_id

func finish_match() -> void:
    match_id = ""
    round_id = ""

func finish_round() -> void:
    round_id = ""

func next_event_id() -> String:
    if session_id.is_empty():
        return ""
    _event_sequence += 1
    return "%s-event-%08d" % [session_id, _event_sequence]

static func load_or_create_installation_id(path: String = DEFAULT_INSTALLATION_PATH) -> String:
    if FileAccess.file_exists(path):
        var existing := FileAccess.open(path, FileAccess.READ)
        if existing != null:
            var value := existing.get_as_text().strip_edges()
            existing.close()
            if not value.is_empty():
                return value
    var directory := path.get_base_dir()
    var absolute_directory := ProjectSettings.globalize_path(directory)
    if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
        return ""
    var generated := generate_id("installation")
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return ""
    file.store_string(generated)
    var write_error := file.get_error()
    file.close()
    return generated if write_error == OK else ""

static func generate_id(prefix: String) -> String:
    _process_nonce += 1
    var bytes := Crypto.new().generate_random_bytes(16)
    var entropy := bytes.hex_encode() if not bytes.is_empty() else "%x" % Time.get_ticks_usec()
    return "%s-%s-%04x" % [prefix, entropy, _process_nonce & 0xffff]
