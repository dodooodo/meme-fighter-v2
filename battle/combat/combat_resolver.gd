# Responsibility: Deterministic contact-to-outcome resolution and authoritative combat application.
# Owns: strike/throw outcome priority, guard/armor/counter handling, reactions, meter/effect application.
# Does NOT own: collision discovery, input sampling, presentation, concrete character-ID branching.
# Dependencies: HitResult, Fighter generic components, GameplayCondition/Effect/Positioning systems.

class_name CombatResolver
extends RefCounted

const CORNER_THRESHOLD_UNITS: int = 12000

var temporary_entities: TemporaryEntitySystem = null
var effect_executor: GameplayEffectExecutor = GameplayEffectExecutor.new()
var positioning_system: PositioningSystem = PositioningSystem.new()
var stage_left_units: int = 8000
var stage_right_units: int = 120000

func configure(temp_entities: TemporaryEntitySystem, stage_left: int, stage_right: int) -> void:
    temporary_entities = temp_entities
    stage_left_units = stage_left
    stage_right_units = stage_right

func resolve_strike_contact(contact: StrikeContact, attacker: Fighter, defender: Fighter) -> HitResult:
    if contact == null or attacker == null or defender == null: return null
    var move := attacker.move_registry.get_move(contact.move_id)
    if move == null: return null
    var payload = move.payload_for_hit_id(contact.hit_id)
    if payload == null: return null
    var flags := GameplayConditionEvaluator.contact_flags(defender)
    if payload is MoveHitData and not GameplayConditionEvaluator.matches_all(payload.conditions, attacker, defender, flags, temporary_entities):
        return null
    return _resolve_strike_payload(contact, payload, move, attacker, defender, HitResult.AttackSourceKind.FIGHTER_BODY, 0, &"", flags)

func resolve_projectile_contact(contact: ProjectileContact, projectile_data: ProjectileData, attacker: Fighter, defender: Fighter) -> HitResult:
    if contact == null or projectile_data == null or attacker == null or defender == null: return null
    var flags := GameplayConditionEvaluator.contact_flags(defender)
    return _resolve_strike_payload(contact, projectile_data, null, attacker, defender, HitResult.AttackSourceKind.PROJECTILE, contact.projectile_instance_id, contact.projectile_id, flags)

func resolve_world_result(result: HitResult, attacker: Fighter, defender: Fighter) -> HitResult:
    if result == null or attacker == null or defender == null: return null
    result.contact_flags = GameplayConditionEvaluator.contact_flags(defender)
    if defender.mechanics_runtime.counter_active(defender.move_runner, result.attack_source_kind):
        result.result_type = HitResult.ResultType.COUNTERED
        result.counter_success_move_id = defender.mechanics_runtime.counter_success_move_id(defender.move_runner)
    elif defender.mechanics_runtime.last_stand_active:
        result.result_type = HitResult.ResultType.ARMOR
    elif defender.mechanics_runtime.armor_active(defender.move_runner, result.attack_source_kind):
        result.result_type = HitResult.ResultType.ARMOR
    elif _is_guarding(defender) and _can_guard_hit_level(defender.state_machine.guard_posture, result.hit_level):
        result.result_type = HitResult.ResultType.BLOCK
        result.damage = 0
        result.hitstun_frames = 0
    return result

func resolve_throw_contact(contact: ThrowContact, attacker: Fighter, defender: Fighter) -> HitResult:
    if contact == null or attacker == null or defender == null: return null
    var move := attacker.move_registry.get_move(contact.move_id)
    if move == null or move.throw_box == null: return null
    var flags := GameplayConditionEvaluator.contact_flags(defender)
    if not GameplayConditionEvaluator.matches_all(move.throw_conditions, attacker, defender, flags, temporary_entities): return null
    var result := HitResult.new()
    result.result_type = HitResult.ResultType.THROW; result.attacker_id = contact.attacker_id; result.defender_id = contact.defender_id
    result.move_id = contact.move_id; result.attack_instance_id = contact.attack_instance_id; result.damage = move.damage
    result.hitstop_attacker = move.hitstop_attacker; result.hitstop_defender = move.hitstop_defender
    result.knockback_x_units = move.knockback_x_units * attacker.movement_motor.facing; result.knockback_y_units = move.knockback_y_units
    result.hit_position = contact.hit_position; result.causes_knockdown = move.causes_knockdown
    result.reaction_type = move.reaction_type if move.reaction_type != CombatReaction.Type.NONE else (CombatReaction.Type.HARD_KNOCKDOWN if move.causes_knockdown else CombatReaction.Type.NONE)
    result.throw_hold_frames = move.throw_hold_frames; result.knockdown_frames = move.knockdown_frames; result.getup_frames = defender.data.default_getup_frames
    result.meter_gain_on_throw = move.meter_gain_on_throw; result.contact_flags = flags
    _copy_observation_facts(result, attacker, defender, flags)
    result.on_hit_effects = move.on_hit_effects.duplicate()
    return result

func apply_strike_result(frame_number: int, result: HitResult, attacker: Fighter, defender: Fighter, event_queue: Array[CombatEvent]) -> bool:
    if result == null or attacker == null or defender == null: return false
    match result.result_type:
        HitResult.ResultType.HIT: _apply_hit(frame_number, result, attacker, defender, event_queue)
        HitResult.ResultType.BLOCK: _apply_block(frame_number, result, attacker, defender, event_queue)
        HitResult.ResultType.ARMOR: _apply_armor(frame_number, result, attacker, defender, event_queue)
        HitResult.ResultType.COUNTERED: _apply_countered(result, attacker, defender)
        _: return false
    return true

func apply_throw_result(frame_number: int, result: HitResult, attacker: Fighter, defender: Fighter, event_queue: Array[CombatEvent]) -> void:
    if result == null or result.result_type != HitResult.ResultType.THROW or attacker == null or defender == null: return
    var hp_before := defender.combatant.hp
    if defender.mechanics_runtime.last_stand_active:
        defender.mode.exit_mode()
        defender.sync_mechanics_from_mode()
    defender.move_runner.interrupt(); defender.mechanics_runtime.armor_remaining_hits = 0; defender.mechanics_runtime.counter_attack_instance_id = 0
    defender.combatant.receive_throw_damage(result.damage, result.hitstop_defender); defender.combatant.last_result_type = HitResult.ResultType.THROW
    attacker.combatant.apply_attacker_hitstop(result.hitstop_attacker); attacker.hitbox_owner.record_hit(result.attack_instance_id, defender.fighter_id, result.hit_id)
    _award_attacker_meter(result, attacker)
    effect_executor.execute_all(result.on_hit_effects, attacker, defender, temporary_entities, result.contact_flags, stage_left_units, stage_right_units)
    var move := attacker.move_registry.get_move(result.move_id)
    if move != null and move.throw_positioning != null: positioning_system.apply(move.throw_positioning, attacker, defender, stage_left_units, stage_right_units)
    event_queue.append(CombatEvent.throw_event(frame_number, result, hp_before, defender.combatant.hp))
    if defender.combatant.is_ko: event_queue.append(CombatEvent.ko(frame_number, result)); return
    defender.state_machine.enter_thrown(result.throw_hold_frames, result.knockdown_frames, result.getup_frames, defender.input_buffer)

func _resolve_strike_payload(contact: StrikeContact, payload, move: MoveData, attacker: Fighter, defender: Fighter, source_kind: int, source_runtime_id: int, projectile_id: StringName, flags: int) -> HitResult:
    var result := _base_result(contact, payload, move, attacker, defender)
    result.attack_source_kind = source_kind; result.source_runtime_id = source_runtime_id; result.projectile_id = projectile_id; result.contact_flags = flags
    # Counter and Last Stand intercept before ordinary damage/guard. Throws use a separate path and therefore always beat these.
    if defender.mechanics_runtime.counter_active(defender.move_runner, source_kind):
        result.result_type = HitResult.ResultType.COUNTERED; result.damage = 0; result.counter_success_move_id = defender.mechanics_runtime.counter_success_move_id(defender.move_runner); return result
    if defender.mechanics_runtime.last_stand_active:
        result.result_type = HitResult.ResultType.ARMOR; return result
    if _is_guarding(defender) and _is_attack_from_front(contact, defender) and _can_guard_hit_level(defender.state_machine.guard_posture, result.hit_level):
        result.result_type = HitResult.ResultType.BLOCK; result.damage = 0; result.hitstun_frames = 0; result.knockback_x_units = 0; result.knockback_y_units = 0; return result
    if defender.mechanics_runtime.armor_active(defender.move_runner, source_kind):
        result.result_type = HitResult.ResultType.ARMOR; return result
    result.result_type = HitResult.ResultType.HIT
    result.counter_hit = (flags & GameplayConditionEvaluator.FLAG_COUNTER_HIT) != 0
    if result.counter_hit:
        if payload is MoveHitData:
            result.hitstun_frames += payload.counter_hit_extra_hitstun; result.knockback_x_units += payload.counter_hit_extra_knockback_x_units * attacker.movement_motor.facing
            if payload.counter_hit_reaction_type != CombatReaction.Type.NONE: result.reaction_type = payload.counter_hit_reaction_type
        elif move != null:
            result.hitstun_frames += move.counter_hit_extra_hitstun_frames; result.knockback_x_units += move.counter_hit_extra_knockback_x_units * attacker.movement_motor.facing
            if move.counter_hit_reaction_type != CombatReaction.Type.NONE: result.reaction_type = move.counter_hit_reaction_type
    return result

func _base_result(contact: StrikeContact, payload, move: MoveData, attacker: Fighter, defender: Fighter) -> HitResult:
    var result := HitResult.new(); result.attacker_id = contact.attacker_id; result.defender_id = contact.defender_id; result.move_id = contact.move_id
    result.attack_instance_id = contact.attack_instance_id; result.hit_id = contact.hit_id; result.damage = payload.damage; result.chip_damage = payload.chip_damage
    result.hitstun_frames = payload.hitstun_frames; result.blockstun_frames = payload.blockstun_frames; result.hitstop_attacker = payload.hitstop_attacker; result.hitstop_defender = payload.hitstop_defender
    result.knockback_x_units = payload.knockback_x_units * attacker_facing_for_knockback(contact); result.knockback_y_units = payload.knockback_y_units
    result.hit_position = contact.hit_position; result.hit_level = payload.hit_level; result.incoming_direction_x = contact.incoming_direction_x
    result.meter_gain_on_hit = payload.meter_gain_on_hit if payload.get("meter_gain_on_hit") != null else (move.meter_gain_on_hit if move != null else 0)
    result.meter_gain_on_block = payload.meter_gain_on_block if payload.get("meter_gain_on_block") != null else (move.meter_gain_on_block if move != null else 0)
    result.reaction_type = payload.reaction_type if payload.get("reaction_type") != null else (move.reaction_type if move != null else CombatReaction.Type.NONE)
    result.defender_block_pushback_units = payload.defender_block_pushback_units if payload.get("defender_block_pushback_units") != null else (move.defender_block_pushback_units if move != null else 0)
    result.attacker_block_recoil_units = payload.attacker_block_recoil_units if payload.get("attacker_block_recoil_units") != null else (move.attacker_block_recoil_units if move != null else 0)
    if payload is MoveHitData:
        result.knockdown_frames = payload.knockdown_frames; result.getup_frames = payload.getup_frames if payload.getup_frames > 0 else defender.data.default_getup_frames
        result.on_hit_effects = payload.on_hit_effects.duplicate(); result.on_block_effects = payload.on_block_effects.duplicate()
    elif payload is ProjectileData:
        result.knockdown_frames = 0; result.getup_frames = defender.data.default_getup_frames
        result.on_hit_effects = payload.on_hit_effects.duplicate(); result.on_block_effects = payload.on_block_effects.duplicate()
    elif move != null:
        result.knockdown_frames = move.knockdown_frames; result.getup_frames = defender.data.default_getup_frames
    if move != null:
        result.on_hit_effects.append_array(move.on_hit_effects); result.on_block_effects.append_array(move.on_block_effects)
        if result.reaction_type == CombatReaction.Type.NONE and move.causes_knockdown: result.reaction_type = CombatReaction.Type.HARD_KNOCKDOWN
    _copy_observation_facts(result, attacker, defender, result.contact_flags)
    return result

func _copy_observation_facts(result: HitResult, attacker: Fighter, defender: Fighter, flags: int) -> void:
    if result == null or attacker == null or defender == null:
        return
    var attacker_x := attacker.movement_motor.sim_position.x
    var defender_x := defender.movement_motor.sim_position.x
    result.distance_units = absi(attacker_x - defender_x)
    result.attacker_cornered = mini(absi(attacker_x - stage_left_units), absi(stage_right_units - attacker_x)) <= CORNER_THRESHOLD_UNITS
    result.defender_cornered = mini(absi(defender_x - stage_left_units), absi(stage_right_units - defender_x)) <= CORNER_THRESHOLD_UNITS
    result.defender_airborne = (flags & GameplayConditionEvaluator.FLAG_DEFENDER_AIRBORNE) != 0
    result.defender_move_phase = defender.move_runner.phase()

func attacker_facing_for_knockback(contact: StrikeContact) -> int: return -contact.incoming_direction_x
func _is_guarding(defender: Fighter) -> bool: return defender.state_machine.is_guarding()
func _is_attack_from_front(contact: StrikeContact, defender: Fighter) -> bool: return contact.incoming_direction_x == defender.movement_motor.facing
func _can_guard_hit_level(posture: int, hit_level: int) -> bool:
    if posture == FighterStateMachine.GuardPosture.STANDING: return hit_level in [MoveData.HitLevel.HIGH, MoveData.HitLevel.MID]
    if posture == FighterStateMachine.GuardPosture.CROUCHING: return hit_level in [MoveData.HitLevel.MID, MoveData.HitLevel.LOW]
    return false

func _apply_hit(frame_number: int, result: HitResult, attacker: Fighter, defender: Fighter, event_queue: Array[CombatEvent]) -> void:
    var hp_before := defender.combatant.hp; defender.move_runner.interrupt()
    defender.combatant.receive_hit(result.damage, result.hitstun_frames, result.hitstop_defender, result.knockback_x_units, result.knockback_y_units); defender.combatant.last_result_type = HitResult.ResultType.HIT
    attacker.combatant.apply_attacker_hitstop(result.hitstop_attacker); _record_connection(result, attacker, defender, true); _award_attacker_meter(result, attacker)
    effect_executor.execute_all(result.on_hit_effects, attacker, defender, temporary_entities, result.contact_flags, stage_left_units, stage_right_units)
    _apply_reaction(result, defender)
    _grant_successful_hit_status(attacker)
    event_queue.append(CombatEvent.hit(frame_number, result, hp_before, defender.combatant.hp));
    if defender.combatant.is_ko: event_queue.append(CombatEvent.ko(frame_number, result))

func _apply_block(frame_number: int, result: HitResult, attacker: Fighter, defender: Fighter, event_queue: Array[CombatEvent]) -> void:
    var hp_before := defender.combatant.hp
    defender.combatant.receive_block(result.chip_damage, result.blockstun_frames, result.hitstop_defender); defender.combatant.last_result_type = HitResult.ResultType.BLOCK
    attacker.combatant.apply_attacker_hitstop(result.hitstop_attacker); _record_connection(result, attacker, defender, false); _award_attacker_meter(result, attacker)
    positioning_system.apply_block_pushback(result, attacker, defender, stage_left_units, stage_right_units)
    effect_executor.execute_all(result.on_block_effects, attacker, defender, temporary_entities, result.contact_flags, stage_left_units, stage_right_units)
    event_queue.append(CombatEvent.block(frame_number, result, hp_before, defender.combatant.hp))
    if defender.combatant.is_ko: event_queue.append(CombatEvent.ko(frame_number, result))

func _apply_armor(frame_number: int, result: HitResult, attacker: Fighter, defender: Fighter, event_queue: Array[CombatEvent]) -> void:
    var hp_before := defender.combatant.hp
    # Armor/Last Stand takes damage and hitstop but suppresses ordinary hitstun/interruption if alive.
    defender.combatant.hp = clampi(defender.combatant.hp - maxi(0, result.damage), 0, defender.combatant.max_hp)
    defender.combatant.hitstop_remaining = maxi(defender.combatant.hitstop_remaining, result.hitstop_defender)
    defender.combatant.last_result_type = HitResult.ResultType.ARMOR
    attacker.combatant.apply_attacker_hitstop(result.hitstop_attacker); _record_connection(result, attacker, defender, true); _award_attacker_meter(result, attacker)
    if defender.combatant.hp <= 0:
        defender.combatant.is_ko = true; defender.move_runner.interrupt(); event_queue.append(CombatEvent.hit(frame_number, result, hp_before, 0)); event_queue.append(CombatEvent.ko(frame_number, result)); return
    if defender.mechanics_runtime.last_stand_active and defender.data.mechanics != null:
        var rid := defender.data.mechanics.last_stand_resolve_resource_id
        if rid != &"": defender.resources.gain(rid, 1)
    else:
        defender.mechanics_runtime.consume_armor()
    event_queue.append(CombatEvent.hit(frame_number, result, hp_before, defender.combatant.hp))

func _apply_countered(result: HitResult, attacker: Fighter, defender: Fighter) -> void:
    if result.attack_source_kind == HitResult.AttackSourceKind.FIGHTER_BODY: attacker.hitbox_owner.record_hit(result.attack_instance_id, defender.fighter_id, result.hit_id)
    var success := defender.move_registry.get_move(result.counter_success_move_id)
    if success != null:
        defender.move_runner.interrupt(); defender.move_runner.start_move(success); defender.hitbox_owner.begin_attack_instance(defender.move_runner.attack_instance_id); defender.mechanics_runtime.begin_move_defenses(success, defender.move_runner.attack_instance_id); defender.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)

func _record_connection(result: HitResult, attacker: Fighter, defender: Fighter, hit: bool) -> void:
    if result.attack_source_kind != HitResult.AttackSourceKind.FIGHTER_BODY: return
    attacker.hitbox_owner.record_hit(result.attack_instance_id, defender.fighter_id, result.hit_id)
    if hit: attacker.move_runner.mark_connected_hit(result.attack_instance_id)
    else: attacker.move_runner.mark_connected_block(result.attack_instance_id)

func _apply_reaction(result: HitResult, defender: Fighter) -> void:
    if defender.combatant.is_ko: return
    match result.reaction_type:
        CombatReaction.Type.SOFT_KNOCKDOWN, CombatReaction.Type.HARD_KNOCKDOWN, CombatReaction.Type.HEAVY_KNOCKDOWN:
            var kd := result.knockdown_frames if result.knockdown_frames > 0 else (12 if result.reaction_type == CombatReaction.Type.SOFT_KNOCKDOWN else 24)
            defender.state_machine.enter_knockdown(kd, result.getup_frames if result.getup_frames > 0 else defender.data.default_getup_frames, defender.input_buffer)
            if result.reaction_type == CombatReaction.Type.HEAVY_KNOCKDOWN and defender.data.mechanics != null and defender.data.mechanics.heavy_knockdown_resource_id != &"":
                defender.resources.gain(defender.data.mechanics.heavy_knockdown_resource_id, -defender.data.mechanics.heavy_knockdown_resource_loss)
        CombatReaction.Type.WALL_BOUNCE:
            if defender.mechanics_runtime.wall_bounce_available:
                defender.mechanics_runtime.wall_bounce_available = false; defender.combatant.knockback_velocity_x_units = -defender.combatant.knockback_velocity_x_units
        CombatReaction.Type.FORCED_STAND:
            defender.enter_forced_stand(result.hitstun_frames)
        _: pass

func _grant_successful_hit_status(attacker: Fighter) -> void:
    if attacker.data.mechanics == null: return
    var id := attacker.data.mechanics.successful_hit_grants_status_id
    if id != &"": attacker.statuses.apply_defined(id)

func _award_attacker_meter(result: HitResult, attacker: Fighter) -> void:
    var amount := 0
    if result.result_type == HitResult.ResultType.HIT or result.result_type == HitResult.ResultType.ARMOR: amount = result.meter_gain_on_hit
    elif result.result_type == HitResult.ResultType.BLOCK: amount = result.meter_gain_on_block
    elif result.result_type == HitResult.ResultType.THROW: amount = result.meter_gain_on_throw
    attacker.meter.gain(amount)
