# Responsibility: Save ReplayData and return telemetry-safe correlation metadata.
# Owns: replay directory creation, safe replay filename and save-status facts.
# Does NOT own: replay recording/validation, telemetry envelopes, gameplay state, upload.
# Dependencies: ReplayCodec/ReplayData and FileAccess/DirAccess only.
class_name TelemetryReplayStore
extends RefCounted

const DEFAULT_DIRECTORY: String = "user://replays"

static func save(replay_id: String, replay: ReplayData, directory: String = DEFAULT_DIRECTORY) -> Dictionary:
    var result: Dictionary = {
        "replay_id": replay_id,
        "replay_path": "",
        "replay_saved": false,
    }
    var safe_id := _safe_segment(replay_id)
    if safe_id.is_empty() or replay == null or directory.strip_edges().is_empty():
        return result
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
        return result
    var path := directory.path_join("%s%s" % [safe_id, ReplayFormat.FILE_EXTENSION])
    result["replay_path"] = path
    result["replay_saved"] = ReplayCodec.save_to_file(path, replay)
    return result

static func _safe_segment(value: String) -> String:
    var result := ""
    for character in value.strip_edges():
        if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789-_":
            result += character
        else:
            return ""
    return result
