# Responsibility: Build and validate the explicit JSON-safe Telemetry Event Envelope v1.
# Owns: envelope field names, event naming rule, privacy key denylist and JSON-safe normalization.
# Does NOT own: identity persistence, event meaning, buffering, files, HTTP, gameplay state.
# Dependencies: TelemetryIdentity only.
class_name TelemetryEnvelopeV1
extends RefCounted

const VERSION: int = 1
const REQUIRED_KEYS: Array[String] = [
    "event_name", "event_version", "event_id", "occurred_at", "installation_id",
    "session_id", "build_id", "content_version", "platform", "payload",
]
const PRIVATE_PAYLOAD_KEYS: Array[String] = [
    "email", "password", "secret", "token", "raw_input", "input_frames",
    "platform_account_id", "account_id",
]
const OPTIONAL_KEYS: Array[String] = ["match_id", "round_id", "user_id"]

static func create(
    event_name: String,
    payload: Dictionary,
    identity: TelemetryIdentity,
    occurred_at: String,
    build_id: String,
    content_version: String,
    platform: String,
    user_id: String = ""
) -> Dictionary:
    if identity == null:
        return {}
    var normalized_payload: Variant = _normalize_json_value(payload)
    if typeof(normalized_payload) != TYPE_DICTIONARY:
        return {}
    var envelope: Dictionary = {
        "event_name": event_name,
        "event_version": VERSION,
        "event_id": identity.next_event_id(),
        "occurred_at": occurred_at,
        "installation_id": identity.installation_id,
        "session_id": identity.session_id,
        "build_id": build_id,
        "content_version": content_version,
        "platform": platform,
        "payload": normalized_payload,
    }
    if not identity.match_id.is_empty():
        envelope["match_id"] = identity.match_id
    if not identity.round_id.is_empty():
        envelope["round_id"] = identity.round_id
    if not user_id.strip_edges().is_empty():
        envelope["user_id"] = user_id.strip_edges()
    return envelope if is_valid(envelope) else {}

static func is_valid(envelope: Variant) -> bool:
    if typeof(envelope) != TYPE_DICTIONARY:
        return false
    var value: Dictionary = envelope
    for key in REQUIRED_KEYS:
        if not value.has(key):
            return false
    for raw_key: Variant in value:
        if typeof(raw_key) != TYPE_STRING or str(raw_key) not in REQUIRED_KEYS + OPTIONAL_KEYS:
            return false
    if value.get("event_version", 0) != VERSION:
        return false
    for key in ["event_name", "event_id", "occurred_at", "installation_id", "session_id", "build_id", "content_version", "platform"]:
        if typeof(value.get(key)) != TYPE_STRING or str(value[key]).strip_edges().is_empty():
            return false
    if not _valid_event_name(str(value["event_name"])):
        return false
    var timestamp_regex := RegEx.new()
    if timestamp_regex.compile("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$") != OK or timestamp_regex.search(str(value["occurred_at"])) == null:
        return false
    for optional_key in OPTIONAL_KEYS:
        if value.has(optional_key) and (typeof(value[optional_key]) != TYPE_STRING or str(value[optional_key]).strip_edges().is_empty()):
            return false
    return typeof(value["payload"]) == TYPE_DICTIONARY and _normalize_json_value(value["payload"]) != null

static func _valid_event_name(value: String) -> bool:
    if value.is_empty() or value != value.to_lower() or not value.contains("."):
        return false
    var regex := RegEx.new()
    if regex.compile("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$") != OK:
        return false
    return regex.search(value) != null

static func _normalize_json_value(value: Variant) -> Variant:
    if not _is_json_safe(value):
        return null
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
            return value
        TYPE_STRING_NAME:
            return String(value)
        TYPE_FLOAT:
            var number: float = value
            return null if is_nan(number) or is_inf(number) else number
        TYPE_ARRAY:
            var normalized_array: Array = []
            for item: Variant in value:
                normalized_array.append(_normalize_json_value(item))
            return normalized_array
        TYPE_DICTIONARY:
            var normalized_dictionary: Dictionary = {}
            for raw_key: Variant in value:
                if typeof(raw_key) not in [TYPE_STRING, TYPE_STRING_NAME]:
                    return null
                var key := str(raw_key)
                var item: Variant = value[raw_key]
                normalized_dictionary[key] = _normalize_json_value(item)
            return normalized_dictionary
        _:
            return null

static func _is_json_safe(value: Variant) -> bool:
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
            return true
        TYPE_FLOAT:
            var number: float = value
            return not is_nan(number) and not is_inf(number)
        TYPE_ARRAY:
            for item: Variant in value:
                if not _is_json_safe(item):
                    return false
            return true
        TYPE_DICTIONARY:
            for raw_key: Variant in value:
                if typeof(raw_key) not in [TYPE_STRING, TYPE_STRING_NAME]:
                    return false
                if _is_private_payload_key(str(raw_key)) or not _is_json_safe(value[raw_key]):
                    return false
            return true
        _:
            return false

static func _is_private_payload_key(key: String) -> bool:
    var normalized := key.to_lower()
    if normalized in PRIVATE_PAYLOAD_KEYS:
        return true
    for suffix in ["_email", "_password", "_secret", "_token", "_account_id"]:
        if normalized.ends_with(suffix):
            return true
    return false
