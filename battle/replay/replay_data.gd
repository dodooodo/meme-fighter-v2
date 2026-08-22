# Responsibility: Typed replay metadata + complete per-simulation-frame normalized input stream.
# Owns: compatibility IDs/versions, participant character IDs, frames, expected final BattleStateHasher result.
# Does NOT own: Fighter/Projectile snapshots, Resource pointers, Nodes, animation, audio, gameplay state copies.
class_name ReplayData
extends RefCounted

var replay_schema_version: int = ReplayFormat.SCHEMA_VERSION
var combat_rules_version: int = ReplayFormat.COMBAT_RULES_VERSION
var match_rules_id: StringName = &""
var stage_id: StringName = ReplayFormat.DEFAULT_STAGE_ID
var p1_character_id: StringName = &""
var p2_character_id: StringName = &""
var random_seed: int = 0
var initial_simulation_frame: int = 0
var frames: Array[ReplayFramePair] = []
var expected_final_state_hash: String = ""

func frame_count() -> int:
    return frames.size()

func final_frame_number() -> int:
    return frames.back().frame_number if not frames.is_empty() else initial_simulation_frame

func get_frame_pair(frame_number: int) -> ReplayFramePair:
    if frames.is_empty():
        return null
    var index := frame_number - frames[0].frame_number
    if index < 0 or index >= frames.size():
        return null
    var pair := frames[index]
    if pair == null or pair.frame_number != frame_number:
        return null
    return pair

func is_structurally_valid(require_final_hash: bool = true) -> bool:
    if replay_schema_version != ReplayFormat.SCHEMA_VERSION or combat_rules_version != ReplayFormat.COMBAT_RULES_VERSION:
        return false
    if match_rules_id not in [&"versus", &"training"]:
        return false
    if stage_id != ReplayFormat.DEFAULT_STAGE_ID:
        return false
    if p1_character_id == &"" or p2_character_id == &"" or initial_simulation_frame < 0 or frames.is_empty():
        return false
    if require_final_hash and expected_final_state_hash.is_empty():
        return false
    var expected_frame := initial_simulation_frame + 1
    for pair: ReplayFramePair in frames:
        if pair == null or not pair.is_valid() or pair.frame_number != expected_frame:
            return false
        expected_frame += 1
    return true
