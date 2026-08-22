# Responsibility: Development-only sparse combat/state/meter/cancel/projectile lifecycle logger.
# Owns: debug-enabled flag and formatted event lines; never logs every simulation frame/position.
# Does NOT own or mutate gameplay state.
# Dependencies: CombatEvent, HitResult and primitive debug facts only.
class_name CombatLogger
extends RefCounted

var enabled: bool = false
var entries: PackedStringArray = []
var max_entries: int = 256

func _init(p_enabled: bool = false) -> void:
    enabled = p_enabled

func log_state_transition(frame: int, fighter_id: int, from_state: String, to_state: String) -> void:
    if not enabled or from_state == to_state:
        return
    _append("[F%d] P%d %s -> %s" % [frame, fighter_id, from_state, to_state])

func log_move_start(frame: int, fighter_id: int, move_id: StringName) -> void:
    if enabled:
        _append("[F%d] P%d MOVE %s" % [frame, fighter_id, String(move_id)])

func log_cancel(frame: int, fighter_id: int, from_move_id: StringName, to_move_id: StringName) -> void:
    if enabled:
        _append("[F%d] [CANCEL] P%d %s -> %s" % [frame, fighter_id, String(from_move_id), String(to_move_id)])

func log_cancel_meter_denied(frame: int, fighter_id: int, target_move_id: StringName, meter_value: int) -> void:
    if enabled and target_move_id != &"":
        _append("[F%d] [CANCEL] P%d denied meter=%d target=%s" % [frame, fighter_id, meter_value, String(target_move_id)])

func log_meter_gain(frame: int, fighter_id: int, amount: int, new_value: int) -> void:
    if enabled and amount > 0:
        _append("[F%d] [METER] P%d +%d -> %d" % [frame, fighter_id, amount, new_value])

func log_meter_spend(frame: int, fighter_id: int, amount: int, new_value: int) -> void:
    if enabled and amount > 0:
        _append("[F%d] [METER] P%d spend %d -> %d" % [frame, fighter_id, amount, new_value])

func log_projectile_spawn(frame: int, instance_id: int, owner_id: int, projectile_id: StringName, position_units: Vector2i, facing: int) -> void:
    if enabled:
        _append("[F%d] [PROJECTILE] spawn #%d %s owner=P%d pos=(%d,%d) face=%d" % [frame, instance_id, String(projectile_id), owner_id, position_units.x, position_units.y, facing])

func log_projectile_impact(frame: int, instance_id: int, owner_id: int, defender_id: int, projectile_id: StringName, result_type: int) -> void:
    if not enabled:
        return
    var result_name := "hit" if result_type == HitResult.ResultType.HIT else "block"
    _append("[F%d] [PROJECTILE] %s #%d %s P%d->P%d" % [frame, result_name, instance_id, String(projectile_id), owner_id, defender_id])

func log_projectile_despawn(frame: int, instance_id: int, owner_id: int, projectile_id: StringName, reason: StringName) -> void:
    if enabled:
        var verb := "expire" if reason == &"EXPIRE" else "despawn"
        _append("[F%d] [PROJECTILE] %s #%d %s owner=P%d reason=%s" % [frame, verb, instance_id, String(projectile_id), owner_id, String(reason)])

func log_round_start(frame: int, round_number: int, rules_id: StringName) -> void:
    if enabled:
        _append("[F%d] [ROUND] start #%d rules=%s" % [frame, round_number, String(rules_id)])

func log_round_end(frame: int, round_number: int, result: int, timeout: bool, p1_hp: int, p2_hp: int) -> void:
    if not enabled:
        return
    var result_name: String = RoundController.RoundResult.keys()[result] if result >= 0 and result < RoundController.RoundResult.size() else "UNKNOWN"
    var reason := "timeout" if timeout else "KO"
    _append("[F%d] [ROUND] %s #%d result=%s hp=%d/%d" % [frame, reason, round_number, result_name, p1_hp, p2_hp])

func log_round_reset(frame: int, round_number: int) -> void:
    if enabled:
        _append("[F%d] [ROUND] reset -> #%d" % [frame, round_number])

func log_match_winner(frame: int, winner: int, p1_wins: int, p2_wins: int) -> void:
    if not enabled:
        return
    var winner_name: String = RoundController.Participant.keys()[winner] if winner >= 0 and winner < RoundController.Participant.size() else "NONE"
    _append("[F%d] [MATCH] winner=%s score=%d-%d" % [frame, winner_name, p1_wins, p2_wins])

func log_replay(message: String) -> void:
    if enabled:
        _append("[REPLAY] " + message)

func log_combat_event(event: CombatEvent) -> void:
    if not enabled or event == null:
        return
    match event.type:
        CombatEvent.EventType.HIT:
            _append("[F%d] P%d HIT P%d %s" % [event.frame_number, event.attacker_id, event.defender_id, String(event.move_id)])
        CombatEvent.EventType.BLOCK:
            _append("[F%d] P%d BLOCK P%d %s" % [event.frame_number, event.defender_id, event.attacker_id, String(event.move_id)])
        CombatEvent.EventType.THROW:
            _append("[F%d] P%d THROW P%d" % [event.frame_number, event.attacker_id, event.defender_id])
        CombatEvent.EventType.KO:
            _append("[F%d] P%d KO P%d" % [event.frame_number, event.attacker_id, event.defender_id])
        _:
            pass

func _append(line: String) -> void:
    entries.append(line)
    if entries.size() > max_entries:
        entries.remove_at(0)
    print(line)
