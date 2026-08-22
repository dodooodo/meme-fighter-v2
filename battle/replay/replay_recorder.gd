# Responsibility: Observe/copy authoritative normalized InputFrames into typed ReplayData.
# Owns: recording lifecycle and strict frame ordering only.
# Does NOT own/read Fighter state, Projectile state, CombatResolver, keyboard events, or gameplay decisions.
class_name ReplayRecorder
extends RefCounted

var _data: ReplayData = null
var _recording: bool = false
var _finished: bool = false

func begin_recording(
    match_rules_id: StringName,
    p1_character_id: StringName,
    p2_character_id: StringName,
    initial_simulation_frame: int = 0,
    stage_id: StringName = ReplayFormat.DEFAULT_STAGE_ID,
    random_seed: int = 0
) -> bool:
    if match_rules_id == &"" or p1_character_id == &"" or p2_character_id == &"" or initial_simulation_frame < 0:
        return false
    _data = ReplayData.new()
    _data.replay_schema_version = ReplayFormat.SCHEMA_VERSION
    _data.combat_rules_version = ReplayFormat.COMBAT_RULES_VERSION
    _data.match_rules_id = match_rules_id
    _data.stage_id = stage_id
    _data.p1_character_id = p1_character_id
    _data.p2_character_id = p2_character_id
    _data.random_seed = random_seed
    _data.initial_simulation_frame = initial_simulation_frame
    _data.frames.clear()
    _data.expected_final_state_hash = ""
    _recording = true
    _finished = false
    return true

func record_frame(p1_input: InputFrame, p2_input: InputFrame) -> bool:
    if not _recording or _finished or _data == null or p1_input == null or p2_input == null:
        return false
    if p1_input.frame_number != p2_input.frame_number:
        return false
    var expected := _data.initial_simulation_frame + _data.frames.size() + 1
    if p1_input.frame_number != expected:
        return false
    var pair := ReplayFramePair.new(expected, p1_input, p2_input)
    if not pair.is_valid():
        return false
    _data.frames.append(pair)
    return true

func finish_recording(final_state_hash: String) -> bool:
    if not _recording or _finished or _data == null or _data.frames.is_empty() or final_state_hash.is_empty():
        return false
    _data.expected_final_state_hash = final_state_hash
    _recording = false
    _finished = true
    return true

func replay_data() -> ReplayData:
    return _data

func is_recording() -> bool:
    return _recording

func is_finished() -> bool:
    return _finished
