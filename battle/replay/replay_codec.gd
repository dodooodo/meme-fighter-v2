# Responsibility: Explicit ReplayData <-> JSON persistence boundary.
# Owns: scalar-field serialization, strict frame validation, optional FileAccess helpers.
# Does NOT own: BattleSimulation, Resource loading, arbitrary class instantiation, gameplay decisions.
class_name ReplayCodec
extends RefCounted

static func encode_to_string(replay: ReplayData) -> String:
    if replay == null or not replay.is_structurally_valid(true):
        return ""
    var root: Dictionary = {
        "replay_schema_version": replay.replay_schema_version,
        "combat_rules_version": replay.combat_rules_version,
        "match_rules_id": String(replay.match_rules_id),
        "stage_id": String(replay.stage_id),
        "p1_character_id": String(replay.p1_character_id),
        "p2_character_id": String(replay.p2_character_id),
        "random_seed": replay.random_seed,
        "initial_simulation_frame": replay.initial_simulation_frame,
        "expected_final_state_hash": replay.expected_final_state_hash,
        "frames": [],
    }
    var encoded_frames: Array = root["frames"]
    for pair: ReplayFramePair in replay.frames:
        encoded_frames.append({
            "frame_number": pair.frame_number,
            "p1": _encode_input(pair.p1_input),
            "p2": _encode_input(pair.p2_input),
        })
    return JSON.stringify(root)

static func decode_from_string(text: String) -> ReplayData:
    if text.is_empty():
        return null
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return null
    var root: Dictionary = parsed
    var required_keys := [
        "replay_schema_version", "combat_rules_version", "match_rules_id", "stage_id",
        "p1_character_id", "p2_character_id", "random_seed", "initial_simulation_frame",
        "expected_final_state_hash", "frames",
    ]
    for key: String in required_keys:
        if not root.has(key):
            return null
    if typeof(root["frames"]) != TYPE_ARRAY:
        return null

    var replay := ReplayData.new()
    replay.replay_schema_version = _int_value(root["replay_schema_version"], -1)
    replay.combat_rules_version = _int_value(root["combat_rules_version"], -1)
    replay.match_rules_id = StringName(str(root["match_rules_id"]))
    replay.stage_id = StringName(str(root["stage_id"]))
    replay.p1_character_id = StringName(str(root["p1_character_id"]))
    replay.p2_character_id = StringName(str(root["p2_character_id"]))
    replay.random_seed = _int_value(root["random_seed"], 0)
    replay.initial_simulation_frame = _int_value(root["initial_simulation_frame"], -1)
    replay.expected_final_state_hash = str(root["expected_final_state_hash"])

    var raw_frames: Array = root["frames"]
    for raw: Variant in raw_frames:
        if typeof(raw) != TYPE_DICTIONARY:
            return null
        var entry: Dictionary = raw
        if not entry.has("frame_number") or not entry.has("p1") or not entry.has("p2"):
            return null
        if typeof(entry["p1"]) != TYPE_DICTIONARY or typeof(entry["p2"]) != TYPE_DICTIONARY:
            return null
        var frame_number := _int_value(entry["frame_number"], -1)
        var p1 := _decode_input(entry["p1"], frame_number)
        var p2 := _decode_input(entry["p2"], frame_number)
        if p1 == null or p2 == null:
            return null
        replay.frames.append(ReplayFramePair.new(frame_number, p1, p2))
    if not replay.is_structurally_valid(true):
        return null
    return replay

static func save_to_file(path: String, replay: ReplayData) -> bool:
    var encoded := encode_to_string(replay)
    if encoded.is_empty():
        return false
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(encoded)
    file.close()
    return true

static func load_from_file(path: String) -> ReplayData:
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var text := file.get_as_text()
    file.close()
    return decode_from_string(text)

static func _encode_input(frame: InputFrame) -> Dictionary:
    return {
        "frame_number": frame.frame_number,
        "direction_x": frame.direction_x,
        "direction_y": frame.direction_y,
        "held_bits": frame.held_bits,
        "pressed_bits": frame.pressed_bits,
        "released_bits": frame.released_bits,
    }

static func _decode_input(raw: Dictionary, expected_frame: int) -> InputFrame:
    for key: String in ["frame_number", "direction_x", "direction_y", "held_bits", "pressed_bits", "released_bits"]:
        if not raw.has(key):
            return null
    var frame_number := _int_value(raw["frame_number"], -1)
    var direction_x := _int_value(raw["direction_x"], 99)
    var direction_y := _int_value(raw["direction_y"], 99)
    var held_bits := _int_value(raw["held_bits"], -1)
    var pressed_bits := _int_value(raw["pressed_bits"], -1)
    var released_bits := _int_value(raw["released_bits"], -1)
    if frame_number != expected_frame or direction_x < -1 or direction_x > 1 or direction_y < -1 or direction_y > 1:
        return null
    if held_bits < 0 or pressed_bits < 0 or released_bits < 0:
        return null
    if (held_bits & ~ReplayFormat.VALID_INPUT_MASK) != 0 or (pressed_bits & ~ReplayFormat.VALID_INPUT_MASK) != 0 or (released_bits & ~ReplayFormat.VALID_INPUT_MASK) != 0:
        return null
    return InputFrame.new(frame_number, direction_x, direction_y, held_bits, pressed_bits, released_bits)

static func _int_value(value: Variant, fallback: int) -> int:
    if typeof(value) == TYPE_INT:
        return int(value)
    if typeof(value) == TYPE_FLOAT:
        var as_float: float = value
        var as_int := int(as_float)
        return as_int if is_equal_approx(as_float, float(as_int)) else fallback
    return fallback
