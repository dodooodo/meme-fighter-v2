# Responsibility: Derive sparse match/move/mastery analytics records from resolved CombatEvents.
# Owns: event dedupe, move-instance aggregation, combo lifecycle and match summary payload.
# Does NOT own: gameplay decisions, combat mutation, envelopes, identity, files, replay payloads.
# Dependencies: CombatEvent and read-only BattleSimulation facts.
class_name TelemetryMatchAggregator
extends RefCounted

var _active: bool = false
var _completed: bool = false
var _p1_character_id: String = ""
var _p2_character_id: String = ""
var _mode: String = ""
var _replay_id: String = ""
var _start_frame: int = 0
var _current_round: int = 1
var _rounds_ended: int = 0
var _build_id: String = ""
var _content_version: String = ""
var _seen_events: Dictionary = {}
var _move_instances: Dictionary = {}
var _move_stats: Dictionary = {}
var _combos: Dictionary = {}

func begin_match(
    p1_character_id: String,
    p2_character_id: String,
    mode: String,
    replay_id: String,
    initial_frame: int = 0,
    build_id: String = "",
    content_version: String = ""
) -> bool:
    if p1_character_id.is_empty() or p2_character_id.is_empty() or mode not in ["local_2p", "vs_cpu", "online"] or initial_frame < 0:
        return false
    _active = true
    _completed = false
    _p1_character_id = p1_character_id
    _p2_character_id = p2_character_id
    _mode = mode
    _replay_id = replay_id
    _start_frame = initial_frame
    _current_round = 1
    _rounds_ended = 0
    _build_id = build_id
    _content_version = content_version
    _seen_events.clear()
    _move_instances.clear()
    _move_stats.clear()
    _combos.clear()
    return true

func observe(events: Array[CombatEvent], simulation: BattleSimulation) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if not _active or _completed:
        return records
    var latest_event_frame := -1
    for event in events:
        if event == null:
            continue
        latest_event_frame = maxi(latest_event_frame, event.frame_number)
        var event_key := _event_key(event)
        if _seen_events.has(event_key):
            continue
        _seen_events[event_key] = true
        match event.type:
            CombatEvent.EventType.ROUND_STARTED:
                _current_round = maxi(1, event.round_number)
            CombatEvent.EventType.ROUND_ENDED:
                _rounds_ended += 1
            CombatEvent.EventType.MOVE_STARTED:
                _observe_move_started(event)
            CombatEvent.EventType.HIT, CombatEvent.EventType.BLOCK, CombatEvent.EventType.THROW:
                records.append_array(_observe_resolution(event))
            CombatEvent.EventType.KO:
                if event.move_id == MoveIds.ULTIMATE:
                    records.append(_mastery("mastery.ultimate_finish", event, {}))
            _:
                pass
    records.append_array(_settle_combos(simulation, false, latest_event_frame))
    return records

func complete(simulation: BattleSimulation, disconnect_reason: String, replay: Dictionary) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if not _active or _completed or simulation == null:
        return records
    records.append_array(_settle_combos(simulation, true, -1))
    for instance_key: String in _move_instances:
        var instance: Dictionary = _move_instances[instance_key]
        if not bool(instance.get("connected", false)):
            var stats_key: String = instance.get("stats_key", "")
            var stats: Dictionary = _move_stats.get(stats_key, {})
            if not stats.is_empty():
                stats["whiff_count"] = int(stats["whiff_count"]) + 1
    var stat_keys: Array = _move_stats.keys()
    stat_keys.sort()
    for stats_key: Variant in stat_keys:
        var stats: Dictionary = _move_stats[stats_key]
        records.append(_record("move.summary", stats.duplicate(true)))

    var winner_participant := "none"
    var winner := ""
    if simulation.round_controller != null:
        if simulation.round_controller.match_winner == RoundController.Participant.P1:
            winner_participant = "p1"
            winner = _p1_character_id
        elif simulation.round_controller.match_winner == RoundController.Participant.P2:
            winner_participant = "p2"
            winner = _p2_character_id
        elif disconnect_reason == "completed":
            winner_participant = "draw"
            winner = "draw"
    var duration_frames := maxi(0, simulation.frame_number - _start_frame)
    records.append(_record("match.completed", {
        "fighter_ids": [_p1_character_id, _p2_character_id],
        "winner": winner,
        "winner_participant": winner_participant,
        "round_count": maxi(1, maxi(_rounds_ended, _current_round)),
        "match_duration_frames": duration_frames,
        "match_duration_ms": int(round(float(duration_frames) * 1000.0 / 60.0)),
        "mode": _mode,
        "build_id": _build_id,
        "content_version": _content_version,
        "disconnect_reason": disconnect_reason if not disconnect_reason.is_empty() else "unknown",
        "replay_id": replay.get("replay_id", _replay_id),
        "replay_path": replay.get("replay_path", ""),
        "replay_saved": replay.get("replay_saved", false),
    }))
    _completed = true
    _active = false
    return records

func is_active() -> bool:
    return _active and not _completed

func _observe_move_started(event: CombatEvent) -> void:
    if event.attacker_id < 1 or event.move_id == &"" or event.attack_instance_id <= 0:
        return
    var instance_key := _instance_key(event.attacker_id, event.attack_instance_id)
    if _move_instances.has(instance_key):
        return
    var stats_key := _stats_key(event.attacker_id, event.move_id)
    var stats := _ensure_stats(event.attacker_id, event.move_id)
    stats["use_count"] = int(stats["use_count"]) + 1
    _move_instances[instance_key] = {"stats_key": stats_key, "connected": false}

func _observe_resolution(event: CombatEvent) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if event.attacker_id < 1 or event.move_id == &"":
        return records
    var stats_key := _stats_key(event.attacker_id, event.move_id)
    var stats := _ensure_stats(event.attacker_id, event.move_id)
    var instance_key := _instance_key(event.attacker_id, event.attack_instance_id)
    if not _move_instances.has(instance_key):
        _move_instances[instance_key] = {"stats_key": stats_key, "connected": true}
    else:
        _move_instances[instance_key]["connected"] = true
    match event.type:
        CombatEvent.EventType.HIT:
            stats["hit_count"] = int(stats["hit_count"]) + 1
            _observe_hit_combo(event)
            if event.defender_airborne:
                records.append(_mastery("mastery.anti_air_success", event, {}))
            if event.defender_move_phase == &"RECOVERY":
                stats["punish_count"] = int(stats["punish_count"]) + 1
                records.append(_mastery("mastery.whiff_punish_success", event, {}))
            if event.counter_hit:
                stats["counter_hit_count"] = int(stats["counter_hit_count"]) + 1
        CombatEvent.EventType.BLOCK:
            stats["block_count"] = int(stats["block_count"]) + 1
            records.append(_mastery("mastery.guard_success", event, {"fighter_id": event.defender_id, "opponent_id": event.attacker_id}))
        CombatEvent.EventType.THROW:
            stats["hit_count"] = int(stats["hit_count"]) + 1
            records.append(_mastery("mastery.throw_success", event, {}))
    stats["damage"] = int(stats["damage"]) + maxi(0, event.value_before - event.value_after)
    var distance_bucket := _distance_bucket(event.distance_units)
    stats["distance_buckets"][distance_bucket] = int(stats["distance_buckets"][distance_bucket]) + 1
    var corner_state := _corner_state(event.attacker_cornered, event.defender_cornered)
    stats["corner_states"][corner_state] = int(stats["corner_states"][corner_state]) + 1
    return records

func _observe_hit_combo(event: CombatEvent) -> void:
    var key := str(event.attacker_id)
    var combo: Dictionary = _combos.get(key, {
        "attacker_id": event.attacker_id,
        "defender_id": event.defender_id,
        "hit_count": 0,
        "damage": 0,
        "last_frame": event.frame_number,
        "move_ids": [],
    })
    combo["hit_count"] = int(combo["hit_count"]) + 1
    combo["damage"] = int(combo["damage"]) + maxi(0, event.value_before - event.value_after)
    combo["last_frame"] = event.frame_number
    var move_ids: Array = combo["move_ids"]
    var move_id := String(event.move_id)
    if not move_ids.has(move_id):
        move_ids.append(move_id)
    _combos[key] = combo

func _settle_combos(simulation: BattleSimulation, force: bool, latest_event_frame: int) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var keys: Array = _combos.keys()
    for raw_key: Variant in keys:
        var key := str(raw_key)
        var combo: Dictionary = _combos[key]
        if not force and int(combo["last_frame"]) == latest_event_frame:
            continue
        var defender: Fighter = simulation.fighter_by_id(int(combo["defender_id"])) if simulation != null else null
        if not force and defender != null and defender.combatant.hitstun_remaining > 0:
            continue
        if int(combo["hit_count"]) >= 2:
            records.append(_record("mastery.combo_completion", combo.duplicate(true)))
        _combos.erase(key)
    return records

func _ensure_stats(fighter_id: int, move_id: StringName) -> Dictionary:
    var key := _stats_key(fighter_id, move_id)
    if not _move_stats.has(key):
        _move_stats[key] = {
            "fighter_id": fighter_id,
            "move_id": String(move_id),
            "use_count": 0,
            "hit_count": 0,
            "block_count": 0,
            "whiff_count": 0,
            "punish_count": 0,
            "counter_hit_count": 0,
            "damage": 0,
            "distance_buckets": {"close": 0, "mid": 0, "far": 0},
            "corner_states": {"midscreen": 0, "attacker_cornered": 0, "defender_cornered": 0, "both_cornered": 0},
        }
    return _move_stats[key]

func _mastery(event_name: String, event: CombatEvent, extra: Dictionary) -> Dictionary:
    var payload: Dictionary = {
        "fighter_id": event.attacker_id,
        "opponent_id": event.defender_id,
        "move_id": String(event.move_id),
        "round_number": _current_round,
        "simulation_frame": event.frame_number,
    }
    payload.merge(extra, true)
    return _record(event_name, payload)

func _record(event_name: String, payload: Dictionary) -> Dictionary:
    return {"event_name": event_name, "payload": payload}

func _event_key(event: CombatEvent) -> String:
    return "%d:%d:%d:%d:%s:%d:%d:%d:%d" % [event.type, event.frame_number, event.attacker_id, event.defender_id, String(event.move_id), event.attack_instance_id, event.projectile_instance_id, event.hit_id, event.round_number]

func _instance_key(fighter_id: int, instance_id: int) -> String:
    return "%d:%d" % [fighter_id, instance_id]

func _stats_key(fighter_id: int, move_id: StringName) -> String:
    return "%d:%s" % [fighter_id, String(move_id)]

func _distance_bucket(distance_units: int) -> String:
    if distance_units <= 12000:
        return "close"
    if distance_units <= 32000:
        return "mid"
    return "far"

func _corner_state(attacker_cornered: bool, defender_cornered: bool) -> String:
    if attacker_cornered and defender_cornered:
        return "both_cornered"
    if attacker_cornered:
        return "attacker_cornered"
    if defender_cornered:
        return "defender_cornered"
    return "midscreen"
