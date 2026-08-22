# Read-only HUD projection of authoritative state.
class_name BattleHudViewModel
extends RefCounted

var p1_name: String = "P1"
var p2_name: String = "P2"
var p1_hp: int = 0
var p1_max_hp: int = 1
var p2_hp: int = 0
var p2_max_hp: int = 1
var p1_meter: int = 0
var p2_meter: int = 0
var p1_wins: int = 0
var p2_wins: int = 0
var timer_text: String = "0"
var round_text: String = "ROUND 1"
var state_text: String = "ROUND_ACTIVE"
var training: bool = false

func update_from(simulation: BattleSimulation, p1_data: CharacterPresentationData = null, p2_data: CharacterPresentationData = null) -> void:
    if simulation == null:
        return
    p1_name = p1_data.display_name if p1_data != null and not p1_data.display_name.is_empty() else String(simulation.fighter_a.data.id)
    p2_name = p2_data.display_name if p2_data != null and not p2_data.display_name.is_empty() else String(simulation.fighter_b.data.id)
    p1_hp = simulation.fighter_a.combatant.hp
    p1_max_hp = simulation.fighter_a.combatant.max_hp
    p2_hp = simulation.fighter_b.combatant.hp
    p2_max_hp = simulation.fighter_b.combatant.max_hp
    p1_meter = simulation.fighter_a.meter.get_value()
    p2_meter = simulation.fighter_b.meter.get_value()
    var round := simulation.round_controller
    p1_wins = round.p1_round_wins
    p2_wins = round.p2_round_wins
    training = round.rules != null and round.rules.mode == MatchRulesData.Mode.TRAINING
    timer_text = "∞" if training or (round.rules != null and not round.rules.timer_enabled) else str(round.timer_display_seconds())
    round_text = "ROUND %d" % round.round_number
    state_text = round.state_name()
