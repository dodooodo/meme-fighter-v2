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
# Observer-only baseline for generic meter/resource/status/mode/entity diffs. Never snapshotted or hashed.
var _last_observable_state: Dictionary = {}

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
    _last_observable_state.clear()
    return true

func observe(events: Array[CombatEvent], simulation: BattleSimulation) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if not _active or _completed:
        return records
    var had_observable_baseline := not _last_observable_state.is_empty()
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
                if _is_ultimate_event(event, simulation):
                    records.append(_mastery("mastery.ultimate_finish", event, {}))
            _:
                pass
        records.append_array(_event_records(event, simulation))
    records.append_array(_settle_open_move_instances(simulation, false))
    records.append_array(_settle_combos(simulation, false, latest_event_frame))
    if simulation != null:
        var current_state := _capture_observable_state(simulation)
        if had_observable_baseline:
            records.append_array(_state_diff_records(_last_observable_state, current_state, simulation.frame_number))
        _last_observable_state = current_state
    return records

func complete(simulation: BattleSimulation, disconnect_reason: String, replay: Dictionary) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if not _active or _completed or simulation == null:
        return records
    records.append_array(_settle_open_move_instances(simulation, true))
    records.append_array(_settle_combos(simulation, true, -1))
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
    _move_instances[instance_key] = {"stats_key": stats_key, "connected": false, "closed": false, "fighter_id": event.attacker_id, "move_id": String(event.move_id), "attack_instance_id": event.attack_instance_id}

func _observe_resolution(event: CombatEvent) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if event.attacker_id < 1 or event.move_id == &"":
        return records
    var stats_key := _stats_key(event.attacker_id, event.move_id)
    var stats := _ensure_stats(event.attacker_id, event.move_id)
    var instance_key := _instance_key(event.attacker_id, event.attack_instance_id)
    if not _move_instances.has(instance_key):
        _move_instances[instance_key] = {"stats_key": stats_key, "connected": true, "closed": false, "fighter_id": event.attacker_id, "move_id": String(event.move_id), "attack_instance_id": event.attack_instance_id}
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
    stats["raw_damage"] = int(stats["raw_damage"]) + maxi(0, event.raw_damage)
    stats["scaled_damage"] = int(stats["scaled_damage"]) + maxi(0, event.scaled_damage)
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
            "raw_damage": 0,
            "scaled_damage": 0,
            "distance_buckets": {"close": 0, "mid": 0, "far": 0},
            "corner_states": {"midscreen": 0, "attacker_cornered": 0, "defender_cornered": 0, "both_cornered": 0},
        }
    return _move_stats[key]


func _event_records(event: CombatEvent, simulation: BattleSimulation) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    if event == null:
        return records
    match event.type:
        CombatEvent.EventType.MOVE_STARTED:
            var start_payload := _event_payload(event, simulation)
            records.append(_record("combat.move_start", start_payload))
            var charge_level := _charge_level_for_started_move(event, simulation)
            if charge_level > 0:
                var charge_payload := start_payload.duplicate(true)
                charge_payload["charge_level"] = charge_level
                records.append(_record("combat.charge_level", charge_payload))
            if _is_throw_attempt(event, simulation):
                records.append(_record("combat.throw_attempt", start_payload.duplicate(true)))
            if _is_ultimate_event(event, simulation):
                records.append(_record("combat.ultimate_start", start_payload.duplicate(true)))
        CombatEvent.EventType.HIT:
            var hit_payload := _event_payload(event, simulation)
            _add_combo_payload(hit_payload, event.attacker_id)
            records.append(_record("combat.hit", hit_payload))
            if event.counter_hit:
                records.append(_record("combat.counter_hit", hit_payload.duplicate(true)))
            if event.defender_move_phase == &"RECOVERY":
                records.append(_record("combat.punish", hit_payload.duplicate(true)))
            if event.attack_source_kind == HitResult.AttackSourceKind.PROJECTILE:
                records.append(_record("combat.projectile_hit", hit_payload.duplicate(true)))
            elif event.attack_source_kind == HitResult.AttackSourceKind.TEMPORARY_ENTITY:
                records.append_array(_temporary_source_hit_records(event, simulation, hit_payload))
            if _is_ultimate_event(event, simulation):
                records.append(_record("combat.ultimate_hit", hit_payload.duplicate(true)))
        CombatEvent.EventType.BLOCK:
            var block_payload := _event_payload(event, simulation)
            records.append(_record("combat.block", block_payload))
            if event.attack_source_kind == HitResult.AttackSourceKind.PROJECTILE:
                records.append(_record("combat.projectile_hit", block_payload.duplicate(true)))
            elif event.attack_source_kind == HitResult.AttackSourceKind.TEMPORARY_ENTITY:
                records.append_array(_temporary_source_hit_records(event, simulation, block_payload))
            if _is_ultimate_event(event, simulation):
                records.append(_record("combat.ultimate_block", block_payload.duplicate(true)))
        CombatEvent.EventType.THROW:
            var throw_payload := _event_payload(event, simulation)
            records.append(_record("combat.throw_success", throw_payload))
            if _is_ultimate_event(event, simulation):
                records.append(_record("combat.ultimate_hit", throw_payload.duplicate(true)))
        CombatEvent.EventType.THROW_TECH:
            records.append(_record("combat.throw_tech", _event_payload(event, simulation)))
        CombatEvent.EventType.KO:
            records.append(_record("combat.ko", _event_payload(event, simulation)))
        _:
            pass
    return records

func _event_payload(event: CombatEvent, simulation: BattleSimulation) -> Dictionary:
    var payload: Dictionary = {
        "simulation_tick": event.frame_number,
        "round_index": _current_round,
        "character_id": _character_id_for_fighter(event.attacker_id),
        "opponent_id": _character_id_for_fighter(event.defender_id),
        "attacker_id": event.attacker_id,
        "defender_id": event.defender_id,
        "move_id": String(event.move_id),
        "attack_instance_id": event.attack_instance_id,
        "hit_id": event.hit_id,
        "source_kind": _source_kind_name(event.attack_source_kind),
        "source_runtime_id": event.source_runtime_id,
        "raw_damage": event.raw_damage,
        "scaled_damage": event.scaled_damage,
        "actual_hp_damage": maxi(0, event.value_before - event.value_after),
        "hp_before": event.value_before,
        "hp_after": event.value_after,
        "damage_scale_percent": event.damage_scale_percent,
        "hit_level": _hit_level_name(event.hit_level),
        "counter_hit": event.counter_hit,
        "distance_units": event.distance_units,
        "distance_bucket": _distance_bucket(event.distance_units),
        "corner_state": _corner_state(event.attacker_cornered, event.defender_cornered),
    }
    if event.projectile_id != &"":
        payload["entity_id"] = String(event.projectile_id)
        payload["entity_kind"] = "projectile"
    elif event.attack_source_kind == HitResult.AttackSourceKind.TEMPORARY_ENTITY:
        var info := _temporary_entity_info(event.source_runtime_id, simulation)
        payload["entity_id"] = str(info.get("data_id", ""))
        payload["entity_kind"] = str(info.get("kind_name", "temporary_entity"))
    return payload

func _temporary_source_hit_records(event: CombatEvent, simulation: BattleSimulation, payload: Dictionary) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var info := _temporary_entity_info(event.source_runtime_id, simulation)
    var kind := str(info.get("kind_name", "temporary_entity"))
    if kind == "summon":
        records.append(_record("combat.summon_hit", payload.duplicate(true)))
    elif kind == "area":
        records.append(_record("combat.trap_trigger", payload.duplicate(true)))
    elif kind == "hazard":
        records.append(_record("combat.hazard_hit", payload.duplicate(true)))
    return records

func _settle_open_move_instances(simulation: BattleSimulation, force: bool) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var keys: Array = _move_instances.keys()
    keys.sort()
    for raw_key: Variant in keys:
        var key := str(raw_key)
        var instance: Dictionary = _move_instances[key]
        if bool(instance.get("closed", false)):
            continue
        var fighter_id := int(instance.get("fighter_id", 0))
        var attack_instance_id := int(instance.get("attack_instance_id", 0))
        var fighter := simulation.fighter_by_id(fighter_id) if simulation != null else null
        var fighter_read := fighter.capture_combat_read() if fighter != null else {}
        var still_current := fighter != null and bool(fighter_read.get("current_move_running", false)) and int(fighter_read.get("attack_instance_id", 0)) == attack_instance_id
        if not force and still_current:
            continue
        instance["closed"] = true
        _move_instances[key] = instance
        if bool(instance.get("connected", false)):
            continue
        var stats_key := str(instance.get("stats_key", ""))
        var stats: Dictionary = _move_stats.get(stats_key, {})
        if not stats.is_empty():
            stats["whiff_count"] = int(stats["whiff_count"]) + 1
        var payload := {
            "simulation_tick": simulation.frame_number if simulation != null else 0,
            "round_index": _current_round,
            "character_id": _character_id_for_fighter(fighter_id),
            "fighter_id": fighter_id,
            "move_id": str(instance.get("move_id", "")),
            "attack_instance_id": attack_instance_id,
        }
        records.append(_record("combat.whiff", payload.duplicate(true)))
        if StringName(str(instance.get("move_id", ""))) == MoveIds.ULTIMATE:
            records.append(_record("combat.ultimate_whiff", payload.duplicate(true)))
    return records

func _capture_observable_state(simulation: BattleSimulation) -> Dictionary:
    var out: Dictionary = {"fighters": {}, "projectiles": {}, "temporary_entities": {}}
    if simulation == null:
        return out
    for fighter: Fighter in [simulation.fighter_a, simulation.fighter_b]:
        if fighter == null:
            continue
        var read := fighter.capture_combat_read()
        var statuses: Dictionary = {}
        for state: Dictionary in read["statuses"]:
            statuses[str(state.get("id", ""))] = state.duplicate(true)
        out["fighters"][str(int(read["fighter_id"]))] = {
            "character_id": String(read["character_id"]),
            "meter": int(read["meter"]),
            "resources": (read["resources"] as Dictionary).duplicate(true),
            "statuses": statuses,
            "mode": (read["mode"] as Dictionary).duplicate(true),
            "cornered": _fighter_cornered(fighter, simulation),
        }
    for projectile: ProjectileRuntime in simulation.projectile_system.active_projectiles():
        if projectile == null:
            continue
        out["projectiles"][str(projectile.instance_id)] = {
            "instance_id": projectile.instance_id,
            "owner_fighter_id": projectile.owner_fighter_id,
            "data_id": String(projectile.projectile_id),
            "source_move_id": String(projectile.source_move_id),
            "remaining": projectile.remaining_lifetime_frames,
        }
    for runtime: TemporaryEntityRuntime in simulation.temporary_entity_system.active_entities():
        if runtime == null:
            continue
        var primitive := runtime.capture_primitive()
        primitive["kind_name"] = _temporary_kind_name(runtime.kind)
        out["temporary_entities"][str(runtime.instance_id)] = primitive
    return out

func _state_diff_records(previous: Dictionary, current: Dictionary, frame: int) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var previous_fighters: Dictionary = previous.get("fighters", {})
    var current_fighters: Dictionary = current.get("fighters", {})
    var fighter_keys: Array = current_fighters.keys()
    fighter_keys.sort()
    for raw_key: Variant in fighter_keys:
        var key := str(raw_key)
        if not previous_fighters.has(key):
            continue
        var before: Dictionary = previous_fighters[key]
        var after: Dictionary = current_fighters[key]
        var fighter_id := int(key)
        var base := {
            "simulation_tick": frame,
            "round_index": _current_round,
            "fighter_id": fighter_id,
            "character_id": str(after.get("character_id", "")),
            "opponent_id": _character_id_for_fighter(2 if fighter_id == 1 else 1),
        }
        var meter_before := int(before.get("meter", 0))
        var meter_after := int(after.get("meter", 0))
        if meter_before != meter_after:
            var meter_payload := base.duplicate(true)
            meter_payload["meter_before"] = meter_before
            meter_payload["meter_after"] = meter_after
            meter_payload["meter_delta"] = meter_after - meter_before
            records.append(_record("combat.meter_gain" if meter_after > meter_before else "combat.meter_spend", meter_payload))
        records.append_array(_resource_diff_records(base, before.get("resources", {}), after.get("resources", {})))
        records.append_array(_status_diff_records(base, before.get("statuses", {}), after.get("statuses", {})))
        records.append_array(_mode_diff_records(base, before.get("mode", {}), after.get("mode", {})))
        if bool(before.get("cornered", false)) != bool(after.get("cornered", false)):
            var corner_payload := base.duplicate(true)
            corner_payload["cornered"] = bool(after.get("cornered", false))
            records.append(_record("combat.corner_state", corner_payload))
    records.append_array(_projectile_diff_records(previous.get("projectiles", {}), current.get("projectiles", {}), frame))
    records.append_array(_temporary_entity_diff_records(previous.get("temporary_entities", {}), current.get("temporary_entities", {}), frame))
    return records

func _resource_diff_records(base: Dictionary, before_value: Variant, after_value: Variant) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var before: Dictionary = before_value if before_value is Dictionary else {}
    var after: Dictionary = after_value if after_value is Dictionary else {}
    var ids: Dictionary = {}
    for key: Variant in before.keys(): ids[str(key)] = true
    for key: Variant in after.keys(): ids[str(key)] = true
    var keys: Array = ids.keys(); keys.sort()
    for raw_id: Variant in keys:
        var id := str(raw_id)
        var old_value := int(before.get(id, 0))
        var new_value := int(after.get(id, 0))
        if old_value == new_value:
            continue
        var payload := base.duplicate(true)
        payload["resource_id"] = id
        payload["value_before"] = old_value
        payload["value_after"] = new_value
        payload["delta"] = new_value - old_value
        records.append(_record("combat.resource_change", payload))
    return records

func _status_diff_records(base: Dictionary, before_value: Variant, after_value: Variant) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var before: Dictionary = before_value if before_value is Dictionary else {}
    var after: Dictionary = after_value if after_value is Dictionary else {}
    var ids: Dictionary = {}
    for key: Variant in before.keys(): ids[str(key)] = true
    for key: Variant in after.keys(): ids[str(key)] = true
    var keys: Array = ids.keys(); keys.sort()
    for raw_id: Variant in keys:
        var id := str(raw_id)
        var had := before.has(id)
        var has := after.has(id)
        if not had and has:
            var apply_payload := base.duplicate(true)
            apply_payload["status_id"] = id
            apply_payload["remaining_frames"] = int(after[id].get("remaining", 0))
            apply_payload["application_serial"] = int(after[id].get("serial", 0))
            records.append(_record("combat.status_apply", apply_payload))
        elif had and not has:
            var remove_payload := base.duplicate(true)
            remove_payload["status_id"] = id
            remove_payload["application_serial"] = int(before[id].get("serial", 0))
            records.append(_record("combat.status_remove", remove_payload))
        elif had and has:
            var old_state: Dictionary = before[id]
            var new_state: Dictionary = after[id]
            if not bool(old_state.get("extended_once", false)) and bool(new_state.get("extended_once", false)):
                var extend_payload := base.duplicate(true)
                extend_payload["status_id"] = id
                extend_payload["remaining_before"] = int(old_state.get("remaining", 0))
                extend_payload["remaining_after"] = int(new_state.get("remaining", 0))
                records.append(_record("combat.status_extend", extend_payload))
    return records

func _mode_diff_records(base: Dictionary, before_value: Variant, after_value: Variant) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var before: Dictionary = before_value if before_value is Dictionary else {}
    var after: Dictionary = after_value if after_value is Dictionary else {}
    var old_id := str(before.get("active_mode_id", ""))
    var new_id := str(after.get("active_mode_id", ""))
    if old_id == new_id:
        return records
    if not old_id.is_empty():
        var exit_payload := base.duplicate(true)
        exit_payload["mode_id"] = old_id
        exit_payload["mode_serial"] = int(before.get("mode_serial", 0))
        records.append(_record("combat.mode_exit", exit_payload))
    if not new_id.is_empty():
        var enter_payload := base.duplicate(true)
        enter_payload["mode_id"] = new_id
        enter_payload["mode_serial"] = int(after.get("mode_serial", 0))
        enter_payload["remaining_frames"] = int(after.get("remaining_frames", 0))
        records.append(_record("combat.mode_enter", enter_payload))
    return records

func _projectile_diff_records(before_value: Variant, after_value: Variant, frame: int) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var before: Dictionary = before_value if before_value is Dictionary else {}
    var after: Dictionary = after_value if after_value is Dictionary else {}
    var after_keys: Array = after.keys(); after_keys.sort()
    for raw_key: Variant in after_keys:
        var key := str(raw_key)
        if before.has(key):
            continue
        var info: Dictionary = after[key]
        records.append(_record("combat.projectile_spawn", {
            "simulation_tick": frame, "round_index": _current_round,
            "fighter_id": int(info.get("owner_fighter_id", 0)),
            "character_id": _character_id_for_fighter(int(info.get("owner_fighter_id", 0))),
            "entity_id": str(info.get("data_id", "")), "entity_kind": "projectile",
            "entity_runtime_id": int(info.get("instance_id", 0)), "move_id": str(info.get("source_move_id", "")),
        }))
    return records

func _temporary_entity_diff_records(before_value: Variant, after_value: Variant, frame: int) -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    var before: Dictionary = before_value if before_value is Dictionary else {}
    var after: Dictionary = after_value if after_value is Dictionary else {}
    var after_keys: Array = after.keys(); after_keys.sort()
    for raw_key: Variant in after_keys:
        var key := str(raw_key)
        var info: Dictionary = after[key]
        var kind := str(info.get("kind_name", "temporary_entity"))
        if not before.has(key):
            var spawn_payload := _entity_state_payload(info, frame)
            if kind == "summon": records.append(_record("combat.summon_spawn", spawn_payload))
            elif kind == "area": records.append(_record("combat.trap_spawn", spawn_payload))
            elif kind == "hazard": records.append(_record("combat.hazard_spawn", spawn_payload))
            elif kind == "sequence": records.append(_record("combat.sequence_start", spawn_payload))
        else:
            var old_info: Dictionary = before[key]
            if kind == "area" and not bool(old_info.get("triggered", false)) and bool(info.get("triggered", false)):
                records.append(_record("combat.trap_trigger", _entity_state_payload(info, frame)))
    var before_keys: Array = before.keys(); before_keys.sort()
    for raw_key: Variant in before_keys:
        var key := str(raw_key)
        if after.has(key):
            continue
        var info: Dictionary = before[key]
        var kind := str(info.get("kind_name", "temporary_entity"))
        var payload := _entity_state_payload(info, frame)
        if kind == "summon": records.append(_record("combat.summon_destroyed", payload))
        elif kind == "area": records.append(_record("combat.trap_removed", payload))
        elif kind == "hazard": records.append(_record("combat.hazard_removed", payload))
        elif kind == "sequence": records.append(_record("combat.sequence_end", payload))
    return records

func _entity_state_payload(info: Dictionary, frame: int) -> Dictionary:
    var owner_id := int(info.get("owner_fighter_id", 0))
    return {
        "simulation_tick": frame, "round_index": _current_round,
        "fighter_id": owner_id, "character_id": _character_id_for_fighter(owner_id),
        "entity_runtime_id": int(info.get("instance_id", 0)),
        "entity_id": str(info.get("data_id", "")), "entity_kind": str(info.get("kind_name", "temporary_entity")),
        "hp": int(info.get("hp", 0)), "phase": int(info.get("phase", 0)), "remaining_frames": int(info.get("remaining", 0)),
    }

func _temporary_entity_info(runtime_id: int, simulation: BattleSimulation) -> Dictionary:
    if simulation != null and runtime_id > 0:
        for runtime: TemporaryEntityRuntime in simulation.temporary_entity_system.active_entities():
            if runtime != null and runtime.instance_id == runtime_id:
                var value := runtime.capture_primitive()
                value["kind_name"] = _temporary_kind_name(runtime.kind)
                return value
    var previous_entities: Dictionary = _last_observable_state.get("temporary_entities", {})
    return previous_entities.get(str(runtime_id), {}) if runtime_id > 0 else {}

func _add_combo_payload(payload: Dictionary, attacker_id: int) -> void:
    var combo: Dictionary = _combos.get(str(attacker_id), {})
    payload["combo_hit_count"] = int(combo.get("hit_count", 0))
    payload["combo_damage"] = int(combo.get("damage", 0))

func _is_throw_attempt(event: CombatEvent, simulation: BattleSimulation) -> bool:
    var fighter := simulation.fighter_by_id(event.attacker_id) if simulation != null else null
    var move := fighter.move_registry.get_move(event.move_id) if fighter != null else null
    return move != null and move.throw_box != null

func _is_ultimate_event(event: CombatEvent, simulation: BattleSimulation) -> bool:
    if event.move_id == MoveIds.ULTIMATE:
        return true
    var fighter := simulation.fighter_by_id(event.attacker_id) if simulation != null else null
    var move := fighter.move_registry.get_move(event.move_id) if fighter != null else null
    return move != null and move.tags.has(&"ULTIMATE")

func _charge_level_for_started_move(event: CombatEvent, simulation: BattleSimulation) -> int:
    var fighter := simulation.fighter_by_id(event.attacker_id) if simulation != null else null
    if fighter == null or fighter.data == null or fighter.data.move_set == null:
        return 0
    for move: MoveData in fighter.data.move_set.moves:
        if move == null or move.charge_special_data == null:
            continue
        var charge := move.charge_special_data
        if event.move_id == charge.level_1_move_id: return 1
        if event.move_id == charge.level_2_move_id: return 2
        if event.move_id == charge.level_3_move_id: return 3
    return 0

func _character_id_for_fighter(fighter_id: int) -> String:
    if fighter_id == 1: return _p1_character_id
    if fighter_id == 2: return _p2_character_id
    return ""

func _source_kind_name(kind: int) -> String:
    match kind:
        HitResult.AttackSourceKind.FIGHTER_BODY: return "fighter_body"
        HitResult.AttackSourceKind.PROJECTILE: return "projectile"
        HitResult.AttackSourceKind.TEMPORARY_ENTITY: return "temporary_entity"
    return "unknown"

func _hit_level_name(level: int) -> String:
    match level:
        MoveData.HitLevel.HIGH: return "high_overhead"
        MoveData.HitLevel.LOW: return "low"
    return "mid"

func _temporary_kind_name(kind: int) -> String:
    match kind:
        TemporaryEntityRuntime.Kind.AREA: return "area"
        TemporaryEntityRuntime.Kind.SUMMON: return "summon"
        TemporaryEntityRuntime.Kind.HAZARD: return "hazard"
        TemporaryEntityRuntime.Kind.SEQUENCE: return "sequence"
    return "temporary_entity"

func _fighter_cornered(fighter: Fighter, simulation: BattleSimulation) -> bool:
    if fighter == null or simulation == null:
        return false
    var position := fighter.capture_combat_read()["position_units"] as Vector2i
    var x := position.x
    return x - BattleSimulation.STAGE_LEFT_UNITS <= 12000 or BattleSimulation.STAGE_RIGHT_UNITS - x <= 12000

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
