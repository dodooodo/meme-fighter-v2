# Responsibility: Canonical deterministic debug signature for same-build snapshot/re-simulation tests.
# Does NOT depend on Dictionary iteration order, Resource/Node instance IDs, RID, or memory addresses.
class_name BattleStateHasher
extends RefCounted

static func hash_simulation(simulation: BattleSimulation) -> String:
    return hash_snapshot(simulation.capture_state())

static func hash_snapshot(snapshot: BattleStateSnapshot) -> String:
    return canonical_string(snapshot).sha256_text()

static func canonical_string(snapshot: BattleStateSnapshot) -> String:
    var parts: PackedStringArray = []
    parts.append("v=%d" % snapshot.version)
    parts.append("frame=%d" % snapshot.frame_number)
    _append_round(parts, snapshot.round_state)
    _append_fighter(parts, "P1", snapshot.fighter_a)
    _append_fighter(parts, "P2", snapshot.fighter_b)
    parts.append("projectiles:next=%d:count=%d" % [snapshot.next_projectile_instance_serial, snapshot.projectiles.size()])
    # Snapshot capture uses deterministic ascending ProjectileInstanceID order; include every future-affecting field canonically.
    for s: ProjectileSnapshot in snapshot.projectiles:
        parts.append("proj:%d:owner=%d:move=%s:spawn=%d:id=%s" % [s.instance_id, s.owner_fighter_id, String(s.source_move_id), s.spawn_index, String(s.projectile_id)])
        parts.append("proj:%d:pos=%d,%d:face=%d:life=%d" % [s.instance_id, s.position_units.x, s.position_units.y, s.facing, s.remaining_lifetime_frames])
        parts.append("proj:%d:contact=%s:pending=%d:reason=%s" % [s.instance_id, _ints(s.contacted_defender_ids), _b(s.pending_despawn), String(s.despawn_reason)])
    parts.append("temporary:next=%d:count=%d" % [snapshot.next_temporary_entity_serial, snapshot.temporary_entities.size()])
    for value: Dictionary in snapshot.temporary_entities:
        parts.append("temp=" + _variant_canonical(value))
    return "|".join(parts)

static func _append_round(parts: PackedStringArray, s: RoundStateSnapshot) -> void:
    if s == null:
        parts.append("round=none")
        return
    parts.append("rules=%s" % String(s.rules_id))
    parts.append("round:state=%d:number=%d:wins=%d,%d" % [s.state, s.round_number, s.p1_round_wins, s.p2_round_wins])
    parts.append("round:timer=%d:post=%d:result=%d" % [s.round_timer_remaining_frames, s.post_round_remaining_frames, s.round_result])
    parts.append("round:pending=%d:winner=%d" % [s.pending_match_winner, s.match_winner])

static func _append_fighter(parts: PackedStringArray, prefix: String, s: FighterStateSnapshot) -> void:
    parts.append("%s:id=%d:character=%s" % [prefix, s.fighter_id, String(s.character_id)])
    parts.append("%s:pos=%d,%d" % [prefix, s.sim_position.x, s.sim_position.y])
    parts.append("%s:vel=%d,%d" % [prefix, s.velocity_units.x, s.velocity_units.y])
    parts.append("%s:face=%d:land=%d" % [prefix, s.facing, _b(s.landed_this_frame)])
    parts.append("%s:combat=%d,%d,%d,%d,%d,%d,%d,%d" % [prefix, s.hp, s.hitstun_remaining, s.blockstun_remaining, s.hitstop_remaining, s.knockback_velocity_x_units, s.knockback_velocity_y_units, _b(s.is_ko), s.last_result_type])
    parts.append("%s:meter=%d" % [prefix, s.meter_value])
    parts.append("%s:hfsm=%d,%d,%d,%d,%d" % [prefix, s.root_state, s.state, s.previous_state, s.guard_posture, _b(s.air_attack_available)])
    parts.append("%s:timers=%d,%d,%d,%d,%d,%d,%d,%d,%d" % [prefix, s.landing_remaining, s.dash_move_remaining, s.dash_recovery_remaining, s.thrown_remaining, s.knockdown_remaining, s.getup_remaining, s.pending_knockdown_frames, s.pending_getup_frames, _b(s.jump_started_this_tick)])
    parts.append("%s:charge=%d,%s,%d" % [prefix, s.charge_frames, String(s.charge_entry_move_id), s.charge_locked_facing])
    parts.append("%s:move=%s,%d,%d,%d,%d,%d:spawned=%s" % [prefix, String(s.current_move_id), s.move_frame, s.attack_instance_id, s.next_attack_instance_serial, _b(s.move_connected_hit), _b(s.move_connected_block), _ints(s.move_spawned_projectile_indices)])
    parts.append("%s:contact=%d:%s:hits=%s" % [prefix, s.tracked_attack_instance_id, _ints(s.contacted_defender_ids), _ints(s.contacted_hit_keys)])
    parts.append("%s:resources=%s" % [prefix, _variant_canonical(s.resource_values)])
    parts.append("%s:statuses=%s:next=%d" % [prefix, _variant_canonical(s.status_states), s.next_status_application_serial])
    parts.append("%s:mode=%s" % [prefix, _variant_canonical(s.mode_state)])
    parts.append("%s:mechanics=%s" % [prefix, _variant_canonical(s.mechanics_state)])
    if s.buffered_intent == null:
        parts.append("%s:buffer=none,%d" % [prefix, s.input_buffer_expiry_frame])
    else:
        var a := s.buffered_intent
        parts.append("%s:buffer=%d,%d,%d,%d,%d,%d,%d,%d" % [prefix, a.action_button, a.source_frame, a.direction_x, a.direction_y, a.facing_at_request, _b(a.forward_held), _b(a.back_held), s.input_buffer_expiry_frame])
    parts.append("%s:history=%d,%d,%d" % [prefix, s.input_history_capacity, s.input_history_write_index, s.input_history_count])
    for i in range(s.input_history_slots.size()):
        var f := s.input_history_slots[i]
        if f == null:
            parts.append("%s:h%d=-" % [prefix, i])
        else:
            parts.append("%s:h%d=%d,%d,%d,%d,%d,%d" % [prefix, i, f.frame_number, f.direction_x, f.direction_y, f.held_bits, f.pressed_bits, f.released_bits])

static func _b(value: bool) -> int:
    return 1 if value else 0

static func _ints(values: Array[int]) -> String:
    var parts: PackedStringArray = []
    for value in values:
        parts.append(str(value))
    return ",".join(parts)

static func _variant_canonical(value: Variant) -> String:
    if value is Dictionary:
        var keys: Array = value.keys()
        keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
        var parts: PackedStringArray = []
        for key in keys:
            parts.append(str(key) + ":" + _variant_canonical(value[key]))
        return "{" + ",".join(parts) + "}"
    if value is Array:
        var parts: PackedStringArray = []
        for item in value:
            parts.append(_variant_canonical(item))
        return "[" + ",".join(parts) + "]"
    if value is Vector2i:
        return "%d,%d" % [value.x, value.y]
    if value is StringName:
        return String(value)
    if value is bool:
        return "1" if value else "0"
    return str(value)
