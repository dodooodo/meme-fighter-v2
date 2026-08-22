# Responsibility: Small playback-setup compatibility validator; never auto-configures or loads gameplay resources.
# Owns: replay metadata checks against an already configured BattleSimulation.
class_name ReplayValidator
extends RefCounted

static func validate_for_simulation(replay: ReplayData, simulation: BattleSimulation) -> bool:
    if replay == null or simulation == null or simulation.round_controller == null:
        return false
    if not replay.is_structurally_valid(true):
        return false
    if replay.stage_id != ReplayFormat.DEFAULT_STAGE_ID:
        return false
    if replay.initial_simulation_frame != simulation.frame_number:
        return false
    if replay.match_rules_id != simulation.round_controller.rules.id:
        return false
    if replay.p1_character_id != simulation.fighter_a.data.id:
        return false
    if replay.p2_character_id != simulation.fighter_b.data.id:
        return false
    return true

static func final_hash_matches(replay: ReplayData, simulation: BattleSimulation) -> bool:
    if replay == null or simulation == null or replay.expected_final_state_hash.is_empty():
        return false
    return simulation.state_signature() == replay.expected_final_state_hash
