# Authoritative manager for Areas, Hazards, Summons and Sequences.
# BattleSimulation is the sole tick authority; data is immutable and runtime state is primitive/snapshot-safe.
class_name TemporaryEntitySystem
extends RefCounted

const INITIAL_INSTANCE_SERIAL: int = 1
var next_instance_serial: int = INITIAL_INSTANCE_SERIAL
var _active: Array[TemporaryEntityRuntime] = []
var _data_registry: Dictionary = {}
# Gate 2 deterministic summon anti-infinite state. Keys are stable primitive strings only.
var _summon_shared_target_lock_remaining: Dictionary = {}
var _summon_rehit_lock_remaining: Dictionary = {}
var _summon_combo_hit_count: Dictionary = {}

func reset_for_new_match() -> void:
    next_instance_serial = INITIAL_INSTANCE_SERIAL
    _active.clear()
    _data_registry.clear()
    _summon_shared_target_lock_remaining.clear()
    _summon_rehit_lock_remaining.clear()
    _summon_combo_hit_count.clear()

func clear_active() -> void:
    _active.clear()
    _summon_shared_target_lock_remaining.clear()
    _summon_rehit_lock_remaining.clear()
    _summon_combo_hit_count.clear()

func active_entities() -> Array[TemporaryEntityRuntime]:
    return _active.duplicate()

func data_for_id(id: StringName) -> Resource:
    # Read-only debug/presentation query; gameplay mutation remains internal.
    return _data_registry.get(id, null) as Resource

func register_data(data: Resource) -> void:
    if data == null:
        return
    var id: StringName = data.get("id") if data.get("id") != null else &""
    if id != &"": _data_registry[id] = data

func spawn_area(owner: Fighter, data: AreaData) -> Array[int]:
    if owner == null or data == null or data.id == &"": return []
    register_data(data)
    if data.replace_group != &"":
        for runtime in _active:
            if runtime.kind == TemporaryEntityRuntime.Kind.AREA and runtime.owner_fighter_id == owner.fighter_id:
                var old := _data_registry.get(runtime.data_id) as AreaData
                if old != null and old.replace_group == data.replace_group: runtime.pending_remove = true
    _remove_pending()
    var runtime := _create(TemporaryEntityRuntime.Kind.AREA, owner, data.id, data.lifetime_frames)
    runtime.position_units += Vector2i(data.offset_units.x * owner.movement_motor.facing, data.offset_units.y)
    return [runtime.instance_id]

func spawn_hazard(owner: Fighter, data: HazardData, position_override: Vector2i = Vector2i(2147483647, 2147483647)) -> Array[int]:
    if owner == null or data == null or data.id == &"": return []
    register_data(data)
    var runtime := _create(TemporaryEntityRuntime.Kind.HAZARD, owner, data.id, data.lifetime_frames)
    if position_override.x != 2147483647: runtime.position_units = position_override
    return [runtime.instance_id]

func spawn_summon(owner: Fighter, data: SummonData) -> Array[int]:
    var ids: Array[int] = []
    if owner == null or data == null or data.id == &"": return ids
    register_data(data)
    if data.replace_group != &"":
        for runtime in _active:
            if runtime.kind != TemporaryEntityRuntime.Kind.SUMMON or runtime.owner_fighter_id != owner.fighter_id:
                continue
            var old := _data_registry.get(runtime.data_id) as SummonData
            if old != null and old.replace_group == data.replace_group:
                runtime.pending_remove = true
        _remove_pending()
    for i in range(data.spawn_count):
        var runtime := _create(TemporaryEntityRuntime.Kind.SUMMON, owner, data.id, data.lifetime_frames)
        runtime.hp = data.max_hp
        runtime.position_units += Vector2i((data.spawn_offset_units.x + i * 1600) * owner.movement_motor.facing, data.spawn_offset_units.y)
        runtime.phase_remaining = 0
        if data.spawn_wave_size > 0 and data.spawn_wave_interval_frames > 0:
            runtime.activation_delay_remaining = (i / data.spawn_wave_size) * data.spawn_wave_interval_frames
        ids.append(runtime.instance_id)
    return ids

func spawn_sequence(owner: Fighter, data: SequenceData) -> Array[int]:
    if owner == null or data == null or data.id == &"": return []
    register_data(data)
    var runtime := _create(TemporaryEntityRuntime.Kind.SEQUENCE, owner, data.id, data.duration_frames)
    return [runtime.instance_id]

func _create(kind: int, owner: Fighter, data_id: StringName, lifetime: int) -> TemporaryEntityRuntime:
    var runtime := TemporaryEntityRuntime.new()
    runtime.kind = kind
    runtime.instance_id = next_instance_serial
    next_instance_serial += 1
    runtime.owner_fighter_id = owner.fighter_id
    runtime.data_id = data_id
    runtime.position_units = owner.movement_motor.sim_position
    runtime.facing = owner.movement_motor.facing
    runtime.remaining_lifetime_frames = lifetime
    _active.append(runtime)
    _active.sort_custom(func(a: TemporaryEntityRuntime, b: TemporaryEntityRuntime) -> bool: return a.instance_id < b.instance_id)
    return runtime

func advance_existing(frozen: bool, fighter_a: Fighter, fighter_b: Fighter, max_existing_instance_id: int = 2147483647) -> Array[HitResult]:
    var results: Array[HitResult] = []
    if frozen: return results
    _tick_aux_state(fighter_a, fighter_b)
    for runtime in _active:
        if runtime.pending_remove or runtime.instance_id > max_existing_instance_id: continue
        runtime.age_frames += 1
        runtime.remaining_lifetime_frames -= 1
        var owner := fighter_a if runtime.owner_fighter_id == fighter_a.fighter_id else fighter_b
        var target := fighter_b if owner == fighter_a else fighter_a
        if owner == null or target == null: continue
        match runtime.kind:
            TemporaryEntityRuntime.Kind.AREA: _tick_area(runtime, owner, target, results)
            TemporaryEntityRuntime.Kind.HAZARD: _tick_hazard(runtime, owner, target, results)
            TemporaryEntityRuntime.Kind.SUMMON: _tick_summon(runtime, owner, target, results)
            TemporaryEntityRuntime.Kind.SEQUENCE: _tick_sequence(runtime, owner, target, results)
        if runtime.remaining_lifetime_frames <= 0 or runtime.hp < 0: runtime.pending_remove = true
    _remove_pending()
    return results

func _tick_area(runtime: TemporaryEntityRuntime, owner: Fighter, target: Fighter, results: Array[HitResult]) -> void:
    var data := _data_registry.get(runtime.data_id) as AreaData
    if data == null: runtime.pending_remove = true; return
    # arm_frames is independent from trigger telegraph: an unarmed trap exists but is not yet interactable.
    if not _area_is_armed(runtime, data):
        return
    var inside := _inside_box(target.movement_motor.sim_position, runtime.position_units, data.half_extents_units)
    if inside and data.while_inside_status != null: target.statuses.apply(data.while_inside_status)
    if (runtime.force_triggered or (inside and data.trigger_on_enemy_enter)) and not runtime.triggered:
        runtime.triggered = true; runtime.phase_remaining = data.telegraph_frames
    if runtime.triggered and runtime.phase_remaining > 0:
        runtime.phase_remaining -= 1
    elif runtime.triggered and runtime.phase_remaining == 0 and data.trigger_damage > 0:
        if inside: results.append(_make_world_hit(runtime, owner, target, data.trigger_damage, data.trigger_hitstun_frames, data.trigger_knockback_x_units, MoveData.HitLevel.MID, data.trigger_reaction_type))
        runtime.pending_remove = true

func _tick_hazard(runtime: TemporaryEntityRuntime, owner: Fighter, target: Fighter, results: Array[HitResult]) -> void:
    var data := _data_registry.get(runtime.data_id) as HazardData
    if data == null: runtime.pending_remove = true; return
    if runtime.age_frames <= data.telegraph_frames: return
    if runtime.contacted_fighter_ids.has(target.fighter_id): return
    var inside := _inside_box(target.movement_motor.sim_position, runtime.position_units, data.half_extents_units)
    if data.safe_region_half_width_units > 0 and absi(target.movement_motor.sim_position.x - runtime.position_units.x) <= data.safe_region_half_width_units: inside = false
    if inside:
        results.append(_make_world_hit(runtime, owner, target, data.damage, data.hitstun_frames, data.knockback_x_units, MoveData.HitLevel.MID, data.reaction_type))
        runtime.contacted_fighter_ids.append(target.fighter_id)

func _tick_summon(runtime: TemporaryEntityRuntime, owner: Fighter, target: Fighter, results: Array[HitResult]) -> void:
    var data := _data_registry.get(runtime.data_id) as SummonData
    if data == null: runtime.pending_remove = true; return
    if runtime.hp <= 0: runtime.pending_remove = true; return
    if runtime.activation_delay_remaining > 0:
        runtime.activation_delay_remaining -= 1
        return
    var dx := target.movement_motor.sim_position.x - runtime.position_units.x
    runtime.facing = 1 if dx >= 0 else -1
    if runtime.phase == 0:
        if absi(dx) > data.attack_range_units:
            var step := mini(data.move_speed_units_per_tick, absi(dx))
            var next_x := runtime.position_units.x + runtime.facing * step
            if not data.can_cross_target:
                if runtime.facing > 0:
                    next_x = mini(next_x, target.movement_motor.sim_position.x - 1)
                else:
                    next_x = maxi(next_x, target.movement_motor.sim_position.x + 1)
            runtime.position_units.x = next_x
        else:
            runtime.phase = 1; runtime.phase_remaining = data.attack_startup_frames
    elif runtime.phase == 1:
        runtime.phase_remaining -= 1
        if runtime.phase_remaining <= 0:
            runtime.phase = 2; runtime.phase_remaining = data.attack_active_frames; runtime.attack_serial += 1
    elif runtime.phase == 2:
        if runtime.phase_remaining == data.attack_active_frames and absi(target.movement_motor.sim_position.x - runtime.position_units.x) <= data.attack_range_units:
            var group_id := data.shared_group_id if data.shared_group_id != &"" else data.id
            var rehit_key := _summon_rehit_key(runtime.instance_id, target.fighter_id)
            var group_key := _summon_group_target_key(owner.fighter_id, target.fighter_id, group_id)
            var combo_key := _summon_combo_key(owner.fighter_id, target.fighter_id, group_id)
            var rehit_ready := int(_summon_rehit_lock_remaining.get(rehit_key, 0)) <= 0
            var group_ready := int(_summon_shared_target_lock_remaining.get(group_key, 0)) <= 0
            var combo_hits := int(_summon_combo_hit_count.get(combo_key, 0))
            var combo_budget := data.max_hits_per_owner_combo <= 0 or combo_hits < data.max_hits_per_owner_combo
            if rehit_ready and group_ready and combo_budget:
                var applied_hitstun := data.hitstun_frames
                if data.owner_hitstun_target_hitstun_cap > 0 and (target.combatant.hitstun_remaining > 0 or target.combatant.blockstun_remaining > 0):
                    applied_hitstun = mini(applied_hitstun, data.owner_hitstun_target_hitstun_cap)
                results.append(_make_world_hit(runtime, owner, target, data.damage, applied_hitstun, data.knockback_x_units, MoveData.HitLevel.MID, data.reaction_type))
                if data.same_target_rehit_lockout_frames > 0:
                    _summon_rehit_lock_remaining[rehit_key] = data.same_target_rehit_lockout_frames
                if data.shared_group_target_lockout_frames > 0:
                    _summon_shared_target_lock_remaining[group_key] = data.shared_group_target_lockout_frames
                if data.max_hits_per_owner_combo > 0:
                    _summon_combo_hit_count[combo_key] = combo_hits + 1
        runtime.phase_remaining -= 1
        if runtime.phase_remaining <= 0: runtime.phase = 3; runtime.phase_remaining = data.attack_recovery_frames
    else:
        runtime.phase_remaining -= 1
        if runtime.phase_remaining <= 0: runtime.phase = 0

func _tick_sequence(runtime: TemporaryEntityRuntime, owner: Fighter, target: Fighter, results: Array[HitResult]) -> void:
    var data := _data_registry.get(runtime.data_id) as SequenceData
    if data == null: runtime.pending_remove = true; return
    if data.interruptible_owner_hit and owner.combatant.hitstun_remaining > 0: runtime.pending_remove = true; return
    for i in range(data.steps.size()):
        if (runtime.sequence_step_mask & (1 << i)) != 0: continue
        var step: SequenceStepData = data.steps[i]
        if step == null or runtime.age_frames < step.start_frame: continue
        var record_key := step.record_slot if step.record_slot >= 0 else i
        if step.record_target_position and not runtime.recorded_positions.has(record_key): runtime.recorded_positions[record_key] = target.movement_motor.sim_position
        var fire_frame := step.start_frame + step.telegraph_frames
        if runtime.age_frames < fire_frame: continue
        runtime.sequence_step_mask |= 1 << i
        if step.require_target_status != &"" and not target.statuses.has_status(step.require_target_status): continue
        if step.exclude_target_status != &"" and target.statuses.has_status(step.exclude_target_status): continue
        var center := runtime.position_units + Vector2i(step.offset_units.x * runtime.facing, step.offset_units.y)
        if step.use_recorded_position:
            center = runtime.recorded_positions.get(record_key, target.movement_motor.sim_position)
        if step.safe_region_half_width_units > 0 and absi(target.movement_motor.sim_position.x - center.x) <= step.safe_region_half_width_units: continue
        if _inside_box(target.movement_motor.sim_position, center, step.half_extents_units):
            results.append(_make_world_hit(runtime, owner, target, step.damage, step.hitstun_frames, 0, step.hit_level, step.reaction_type))
            if step.consume_target_status != &"": target.statuses.remove(step.consume_target_status)

func _make_world_hit(runtime: TemporaryEntityRuntime, owner: Fighter, target: Fighter, damage: int, hitstun: int, knockback_x: int, hit_level: int, reaction: int) -> HitResult:
    var result := HitResult.new()
    result.attacker_id = owner.fighter_id; result.defender_id = target.fighter_id
    result.move_id = runtime.data_id; result.attack_instance_id = runtime.instance_id; result.hit_id = runtime.attack_serial
    result.attack_source_kind = HitResult.AttackSourceKind.TEMPORARY_ENTITY; result.source_runtime_id = runtime.instance_id
    result.result_type = HitResult.ResultType.HIT; result.damage = damage; result.hitstun_frames = hitstun
    result.hit_level = hit_level; result.knockback_x_units = knockback_x * runtime.facing; result.reaction_type = reaction
    return result

func apply_incoming_fighter_strikes(attacker: Fighter) -> void:
    if attacker == null or attacker.combatant.is_ko or not attacker.hitbox_owner.has_active_hitbox(attacker.move_runner): return
    var hit_ids := attacker.hitbox_owner.active_hit_ids(attacker.move_runner)
    for hit_id in hit_ids:
        var attack_rect := attacker.hitbox_owner.active_hitbox_rect_for_hit(attacker.position_pixels(), attacker.movement_motor.facing, attacker.move_runner, hit_id)
        for runtime in _active:
            if runtime.kind != TemporaryEntityRuntime.Kind.SUMMON or runtime.owner_fighter_id == attacker.fighter_id or runtime.pending_remove: continue
            var data := _data_registry.get(runtime.data_id) as SummonData
            if data == null: continue
            var center_px := SimulationUnits.vector_units_to_pixels(runtime.position_units)
            var half_px := SimulationUnits.vector_units_to_pixels(data.hurtbox_half_extents_units)
            var rect := Rect2(center_px - half_px, half_px * 2.0)
            var contact_key := attacker.move_runner.attack_instance_id * 1000 + hit_id
            if attack_rect.intersects(rect) and not runtime.contacted_fighter_ids.has(contact_key):
                # Legacy authored moves without per-hit payloads return their
                # MoveData as the canonical fallback. Both MoveData and
                # MoveHitData own damage, so retain that shared payload shape
                # instead of narrowing it to the newer per-hit resource type.
                var payload = attacker.move_runner.payload_for_hit_id(hit_id)
                runtime.hp -= int(payload.damage if payload != null else 0)
                runtime.contacted_fighter_ids.append(contact_key)
                if runtime.hp <= 0: runtime.pending_remove = true
    _remove_pending()

func target_inside_owner_area(owner_id: int, target_position: Vector2i, group_id: StringName) -> bool:
    for runtime in _active:
        if runtime.kind != TemporaryEntityRuntime.Kind.AREA or runtime.owner_fighter_id != owner_id: continue
        var data := _data_registry.get(runtime.data_id) as AreaData
        if data == null: continue
        if group_id != &"" and data.replace_group != group_id: continue
        if not _area_is_armed(runtime, data): continue
        if _inside_box(target_position, runtime.position_units, data.half_extents_units): return true
    return false

func force_trigger_owner_area(owner_id: int, group_id: StringName) -> void:
    for runtime in _active:
        if runtime.kind != TemporaryEntityRuntime.Kind.AREA or runtime.owner_fighter_id != owner_id: continue
        var data := _data_registry.get(runtime.data_id) as AreaData
        if data != null and _area_is_armed(runtime, data) and (group_id == &"" or data.replace_group == group_id): runtime.force_triggered = true

func _area_is_armed(runtime: TemporaryEntityRuntime, data: AreaData) -> bool:
    return runtime != null and data != null and runtime.age_frames >= data.arm_frames

func _tick_aux_state(fighter_a: Fighter, fighter_b: Fighter) -> void:
    _decrement_lock_dictionary(_summon_shared_target_lock_remaining)
    _decrement_lock_dictionary(_summon_rehit_lock_remaining)
    var remove_combo_keys: Array[String] = []
    for key: Variant in _summon_combo_hit_count.keys():
        var parts := String(key).split(":")
        if parts.size() < 2:
            remove_combo_keys.append(String(key)); continue
        var owner_id := int(parts[0])
        var target_id := int(parts[1])
        var owner := fighter_a if fighter_a != null and fighter_a.fighter_id == owner_id else fighter_b
        if owner == null or owner.combo_scaling.hit_count <= 0 or owner.combo_scaling.active_defender_id != target_id:
            remove_combo_keys.append(String(key))
    for key in remove_combo_keys:
        _summon_combo_hit_count.erase(key)

func _decrement_lock_dictionary(values: Dictionary) -> void:
    var remove_keys: Array[String] = []
    for key: Variant in values.keys():
        var remaining := maxi(0, int(values[key]) - 1)
        if remaining <= 0:
            remove_keys.append(String(key))
        else:
            values[key] = remaining
    for key in remove_keys:
        values.erase(key)

func _summon_group_target_key(owner_id: int, target_id: int, group_id: StringName) -> String:
    return "%d:%d:%s" % [owner_id, target_id, String(group_id)]

func _summon_rehit_key(instance_id: int, target_id: int) -> String:
    return "%d:%d" % [instance_id, target_id]

func _summon_combo_key(owner_id: int, target_id: int, group_id: StringName) -> String:
    return _summon_group_target_key(owner_id, target_id, group_id)

func capture_aux_state() -> Dictionary:
    return {
        "shared_target_locks": _copy_int_dictionary(_summon_shared_target_lock_remaining),
        "rehit_locks": _copy_int_dictionary(_summon_rehit_lock_remaining),
        "combo_hit_count": _copy_int_dictionary(_summon_combo_hit_count),
    }

func validate_restore_aux_state(value: Dictionary) -> bool:
    for field in ["shared_target_locks", "rehit_locks", "combo_hit_count"]:
        var entries: Variant = value.get(field, {})
        if not (entries is Dictionary):
            return false
        for key: Variant in entries.keys():
            if String(key).is_empty() or int(entries[key]) < 0:
                return false
    return true

func restore_aux_state(value: Dictionary) -> bool:
    if not validate_restore_aux_state(value):
        return false
    _summon_shared_target_lock_remaining = _copy_int_dictionary(value.get("shared_target_locks", {}))
    _summon_rehit_lock_remaining = _copy_int_dictionary(value.get("rehit_locks", {}))
    _summon_combo_hit_count = _copy_int_dictionary(value.get("combo_hit_count", {}))
    return true

func _copy_int_dictionary(value: Dictionary) -> Dictionary:
    var out: Dictionary = {}
    var keys: Array = value.keys()
    keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
    for key: Variant in keys:
        out[String(key)] = int(value[key])
    return out

func capture_state() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for runtime in _active: out.append(runtime.capture_primitive())
    return out

func validate_restore_state(values: Array[Dictionary], next_serial: int) -> bool:
    var seen: Dictionary = {}
    for value in values:
        var id := int(value.get("instance_id", 0)); var data_id := StringName(str(value.get("data_id", "")))
        if id <= 0 or id >= next_serial or seen.has(id) or not _data_registry.has(data_id): return false
        seen[id] = true
    return true

func restore_state(values: Array[Dictionary], next_serial: int) -> bool:
    if not validate_restore_state(values, next_serial): return false
    _active.clear(); next_instance_serial = next_serial
    for value in values:
        var runtime := TemporaryEntityRuntime.new(); runtime.restore_primitive(value); _active.append(runtime)
    _active.sort_custom(func(a: TemporaryEntityRuntime, b: TemporaryEntityRuntime) -> bool: return a.instance_id < b.instance_id)
    return true

func _inside_box(point: Vector2i, center: Vector2i, half: Vector2i) -> bool:
    return absi(point.x - center.x) <= half.x and absi(point.y - center.y) <= half.y

func _remove_pending() -> void:
    var kept: Array[TemporaryEntityRuntime] = []
    for runtime in _active:
        if not runtime.pending_remove: kept.append(runtime)
    _active = kept

func apply_incoming_projectiles(projectiles: ProjectileSystem) -> void:
    if projectiles == null: return
    for projectile: ProjectileRuntime in projectiles.active_projectiles():
        if projectile.pending_despawn or projectile.projectile_data == null: continue
        var attack_rect := projectile.gameplay_rect()
        for runtime in _active:
            if runtime.kind != TemporaryEntityRuntime.Kind.SUMMON or runtime.owner_fighter_id == projectile.owner_fighter_id or runtime.pending_remove: continue
            var data := _data_registry.get(runtime.data_id) as SummonData
            if data == null: continue
            var center_px := SimulationUnits.vector_units_to_pixels(runtime.position_units)
            var half_px := SimulationUnits.vector_units_to_pixels(data.hurtbox_half_extents_units)
            if attack_rect.intersects(Rect2(center_px - half_px, half_px * 2.0)):
                runtime.hp -= projectile.projectile_data.damage
                projectile.record_contact(-runtime.instance_id, &"SUMMON_HIT")
                if runtime.hp <= 0: runtime.pending_remove = true
                break
    _remove_pending()

func register_fighter_data(fighter: Fighter) -> void:
    if fighter == null or fighter.data == null or fighter.data.move_set == null: return
    for move: MoveData in fighter.data.move_set.moves:
        if move == null: continue
        for effect: GameplayEffectData in move.on_start_effects + move.on_complete_effects + move.on_hit_effects + move.on_block_effects:
            _register_effect_data(effect)
        for hit: MoveHitData in move.hits:
            if hit == null: continue
            for effect: GameplayEffectData in hit.on_hit_effects + hit.on_block_effects: _register_effect_data(effect)
        for spawn: ProjectileSpawnData in move.projectile_spawns:
            if spawn != null and spawn.projectile_data != null: pass

func _register_effect_data(effect: GameplayEffectData) -> void:
    if effect == null:
        return
    if effect.area != null:
        register_data(effect.area)
    if effect.summon != null:
        register_data(effect.summon)
    if effect.hazard != null:
        register_data(effect.hazard)
    if effect.sequence != null:
        register_data(effect.sequence)

func apply_continuous_area_statuses(fighter_a: Fighter, fighter_b: Fighter) -> void:
    for runtime in _active:
        if runtime.kind != TemporaryEntityRuntime.Kind.AREA or runtime.pending_remove: continue
        var data := _data_registry.get(runtime.data_id) as AreaData
        if data == null or data.while_inside_status == null or not _area_is_armed(runtime, data): continue
        var target := fighter_b if runtime.owner_fighter_id == fighter_a.fighter_id else fighter_a
        if target == null: continue
        if _inside_box(target.movement_motor.sim_position, runtime.position_units, data.half_extents_units):
            target.statuses.apply(data.while_inside_status)
        else:
            target.statuses.remove(data.while_inside_status.id)
