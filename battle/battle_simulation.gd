# Responsibility: Authoritative fixed-order battle + match lifecycle tick pipeline.
# Owns: global simulation frame, two Fighters, ProjectileSystem, RoundController, contact build/resolve/apply ordering, event queue.
# Does NOT own: render timing, HUD authority, device-specific polling, wall-clock round timing, replay persistence.
# Dependencies: Fighter, combat/projectile systems, RoundController/MatchRulesData, InputFrame, snapshot codec.
class_name BattleSimulation
extends RefCounted

const STAGE_LEFT_UNITS: int = 8000
const STAGE_RIGHT_UNITS: int = 120000
const GROUND_Y_UNITS: int = 56000

var frame_number: int = 0
var fighter_a: Fighter
var fighter_b: Fighter
var collision_system: CollisionSystem = CollisionSystem.new()
var throw_system: ThrowSystem = ThrowSystem.new()
var projectile_system: ProjectileSystem = ProjectileSystem.new()
var temporary_entity_system: TemporaryEntitySystem = TemporaryEntitySystem.new()
var combat_resolver: CombatResolver = CombatResolver.new()
var round_controller: RoundController = RoundController.new()
var combat_logger: CombatLogger = CombatLogger.new(false)
# Tooling/input-layer observer only; intentionally excluded from Snapshot/Hash gameplay state.
var replay_recorder: ReplayRecorder = null
var _event_queue: Array[CombatEvent] = []
var _start_a: Vector2i = Vector2i(50000, GROUND_Y_UNITS)
var _start_b: Vector2i = Vector2i(78000, GROUND_Y_UNITS)
var _start_facing_a: int = 1
var _start_facing_b: int = -1

func configure(
    character_a: CharacterData,
    character_b: CharacterData,
    source_a: InputSource = null,
    source_b: InputSource = null,
    start_a: Vector2i = Vector2i(50000, GROUND_Y_UNITS),
    start_b: Vector2i = Vector2i(78000, GROUND_Y_UNITS),
    match_rules: MatchRulesData = null
) -> void:
    frame_number = 0
    _event_queue.clear()
    replay_recorder = null
    _start_a = start_a
    _start_b = start_b
    projectile_system = ProjectileSystem.new()
    projectile_system.reset_for_new_match()
    temporary_entity_system = TemporaryEntitySystem.new()
    temporary_entity_system.reset_for_new_match()
    round_controller = RoundController.new()
    if not round_controller.configure(match_rules if match_rules != null else MatchRulesData.versus_defaults()):
        push_error("BattleSimulation could not configure MatchRulesData")
    fighter_a = Fighter.new()
    fighter_b = Fighter.new()
    fighter_a.configure(1, character_a, start_a, STAGE_LEFT_UNITS, STAGE_RIGHT_UNITS, GROUND_Y_UNITS, source_a)
    fighter_b.configure(2, character_b, start_b, STAGE_LEFT_UNITS, STAGE_RIGHT_UNITS, GROUND_Y_UNITS, source_b)
    # Rehydrateable status definitions are shared between both configured fighters; active state remains per Fighter.
    for character in [character_a, character_b]:
        if character != null and character.mechanics != null:
            for status: StatusEffectData in character.mechanics.statuses:
                fighter_a.statuses.register_definition(status)
                fighter_b.statuses.register_definition(status)
    temporary_entity_system.register_fighter_data(fighter_a)
    temporary_entity_system.register_fighter_data(fighter_b)
    combat_resolver.configure(temporary_entity_system, STAGE_LEFT_UNITS, STAGE_RIGHT_UNITS)
    _update_facings()
    _start_facing_a = fighter_a.movement_motor.facing
    _start_facing_b = fighter_b.movement_motor.facing
    _event_queue.append(CombatEvent.round_started(frame_number, round_controller.round_number))

func simulate_frame(input_a: InputFrame, input_b: InputFrame) -> void:
    var next_frame := frame_number + 1
    # Match authority gates input before Fighter consumption and before ReplayRecorder observes the canonical stream.
    var consumed_a := _authoritative_input(input_a, next_frame)
    var consumed_b := _authoritative_input(input_b, next_frame)
    if replay_recorder != null and replay_recorder.is_recording():
        replay_recorder.record_frame(consumed_a, consumed_b)

    if round_controller.is_match_over():
        # Recommended M6 contract: global simulation frame remains monotonic even while gameplay is frozen at MATCH_OVER.
        frame_number = next_frame
        return

    if round_controller.is_post_round():
        _simulate_post_round_tick(next_frame, consumed_a, consumed_b)
        frame_number = next_frame
        return

    _simulate_round_active_tick(next_frame, consumed_a, consumed_b)
    frame_number = next_frame

func sample_and_simulate_frame() -> void:
    var next_frame := frame_number + 1
    simulate_frame(fighter_a.sample_input(next_frame), fighter_b.sample_input(next_frame))

func set_replay_recorder(recorder: ReplayRecorder) -> void:
    replay_recorder = recorder

func drain_events() -> Array[CombatEvent]:
    var drained: Array[CombatEvent] = _event_queue.duplicate()
    _event_queue.clear()
    return drained

func peek_events() -> Array[CombatEvent]:
    return _event_queue.duplicate()

func clear_pending_presentation_events() -> void:
    # Presentation/debug queues are not rollback gameplay state; restore must discard stale pre-restore events.
    _event_queue.clear()

func capture_state() -> BattleStateSnapshot:
    return BattleSnapshotCodec.capture(self)

func restore_state(snapshot: BattleStateSnapshot) -> bool:
    var restored := BattleSnapshotCodec.restore(self, snapshot)
    if restored:
        # Presentation/debug event output is intentionally not rollback state.
        _event_queue.clear()
    return restored

func state_signature() -> String:
    return BattleStateHasher.hash_simulation(self)

func gameplay_hitstop_active() -> bool:
    return (
        (fighter_a != null and fighter_a.combatant.hitstop_remaining > 0)
        or (fighter_b != null and fighter_b.combatant.hitstop_remaining > 0)
    )

func fighter_by_id(fighter_id: int) -> Fighter:
    if fighter_a != null and fighter_a.fighter_id == fighter_id:
        return fighter_a
    if fighter_b != null and fighter_b.fighter_id == fighter_id:
        return fighter_b
    return null

# Round-end cleanup hook. It deliberately preserves per-match detached-entity serials.
func cleanup_temporary_combat_entities() -> void:
    projectile_system.clear_active()
    temporary_entity_system.clear_active()

# Compatibility with M5 tests/debug reset; this is a full projectile-subsystem reset including serial.
func reset_projectiles() -> void:
    projectile_system.reset_for_new_match()

func reset_full_match() -> void:
    frame_number = 0
    _event_queue.clear()
    round_controller.reset_match()
    projectile_system.reset_for_new_match()
    temporary_entity_system.reset_for_new_match()
    temporary_entity_system.register_fighter_data(fighter_a)
    temporary_entity_system.register_fighter_data(fighter_b)
    fighter_a.reset_for_round(_start_a, _start_facing_a, true, true)
    fighter_b.reset_for_round(_start_b, _start_facing_b, true, true)
    _update_facings()
    _event_queue.append(CombatEvent.round_started(frame_number, round_controller.round_number))
    combat_logger.log_round_start(frame_number, round_controller.round_number, round_controller.rules.id)

func reset_training_state() -> void:
    reset_full_match()

func _simulate_round_active_tick(next_frame: int, input_a: InputFrame, input_b: InputFrame) -> void:
    var state_a_before := fighter_a.state_machine.state_name()
    var state_b_before := fighter_b.state_machine.state_name()
    var event_start_index := _event_queue.size()
    var frozen_at_tick_start := gameplay_hitstop_active()
    var max_temp_existing_id := temporary_entity_system.next_instance_serial - 1

    # 1. Canonical normalized inputs.
    fighter_a.ingest_input(input_a)
    fighter_b.ingest_input(input_b)

    # 2. Resolve action starts from canonical move IDs, then execute authored start effects.
    var move_a_before := fighter_a.move_runner.current_move_id()
    var move_b_before := fighter_b.move_runner.current_move_id()
    var instance_a_before := fighter_a.move_runner.attack_instance_id
    var instance_b_before := fighter_b.move_runner.attack_instance_id
    var meter_a_before_start := fighter_a.meter.get_value()
    var meter_b_before_start := fighter_b.meter.get_value()
    var a_started := fighter_a.pre_tick(next_frame)
    var b_started := fighter_b.pre_tick(next_frame)
    if a_started:
        _on_move_started(next_frame, fighter_a, fighter_b)
    if b_started:
        _on_move_started(next_frame, fighter_b, fighter_a)
    fighter_a.sync_mechanics_from_mode()
    fighter_b.sync_mechanics_from_mode()
    if a_started and move_a_before != &"" and instance_a_before != fighter_a.move_runner.attack_instance_id: combat_logger.log_cancel(next_frame, fighter_a.fighter_id, move_a_before, fighter_a.move_runner.current_move_id())
    if b_started and move_b_before != &"" and instance_b_before != fighter_b.move_runner.attack_instance_id: combat_logger.log_cancel(next_frame, fighter_b.fighter_id, move_b_before, fighter_b.move_runner.current_move_id())
    combat_logger.log_meter_spend(next_frame, fighter_a.fighter_id, meter_a_before_start - fighter_a.meter.get_value(), fighter_a.meter.get_value())
    combat_logger.log_meter_spend(next_frame, fighter_b.fighter_id, meter_b_before_start - fighter_b.meter.get_value(), fighter_b.meter.get_value())
    combat_logger.log_cancel_meter_denied(next_frame, fighter_a.fighter_id, fighter_a.state_machine.last_cancel_meter_denied_target, fighter_a.meter.get_value())
    combat_logger.log_cancel_meter_denied(next_frame, fighter_b.fighter_id, fighter_b.state_machine.last_cancel_meter_denied_target, fighter_b.meter.get_value())

    # 3. Persistent area modifiers are authoritative before movement and disappear on exit.
    temporary_entity_system.apply_continuous_area_statuses(fighter_a, fighter_b)

    # 4. Integer fighter movement/pushboxes.
    fighter_a.movement_tick(); fighter_b.movement_tick()
    fighter_a.movement_motor.clamp_x_to_stage(); fighter_b.movement_motor.clamp_x_to_stage()
    collision_system.resolve_pushboxes(fighter_a, fighter_b, STAGE_LEFT_UNITS, STAGE_RIGHT_UNITS)
    fighter_a.movement_motor.clamp_x_to_stage(); fighter_b.movement_motor.clamp_x_to_stage()

    # 5. Detached timelines: only entities that existed at tick start advance.
    projectile_system.advance_existing(frozen_at_tick_start)
    var world_candidates := temporary_entity_system.advance_existing(frozen_at_tick_start, fighter_a, fighter_b, max_temp_existing_id)
    if not frozen_at_tick_start:
        _spawn_move_projectiles(next_frame, fighter_a); _spawn_move_projectiles(next_frame, fighter_b)

    # 6. Fighter/projectile attacks can destroy summons; projectile impact on summon consumes the projectile.
    temporary_entity_system.apply_incoming_fighter_strikes(fighter_a)
    temporary_entity_system.apply_incoming_fighter_strikes(fighter_b)
    temporary_entity_system.apply_incoming_projectiles(projectile_system)

    # 7. Build every fighter-facing contact from one pre-apply state. Multi-hit candidates are canonical hit-id order.
    var strike_contacts: Array[StrikeContact] = []
    strike_contacts.append_array(collision_system.build_strike_contacts(fighter_a, fighter_b))
    strike_contacts.append_array(collision_system.build_strike_contacts(fighter_b, fighter_a))
    strike_contacts = collision_system.apply_clash_priority(strike_contacts, fighter_a, fighter_b)
    var projectile_contacts := projectile_system.build_contacts(fighter_a, fighter_b)
    var throw_a_to_b := throw_system.build_throw_contact(fighter_a, fighter_b)
    var throw_b_to_a := throw_system.build_throw_contact(fighter_b, fighter_a)

    # 8. Resolve all outcomes before authoritative apply; no first-KO early abort.
    var strike_results: Array[HitResult] = []
    for contact: StrikeContact in strike_contacts:
        var attacker := fighter_by_id(contact.attacker_id); var defender := fighter_by_id(contact.defender_id)
        var result := combat_resolver.resolve_strike_contact(contact, attacker, defender)
        if result != null: strike_results.append(result)
    var projectile_results: Array[HitResult] = []
    for contact: ProjectileContact in projectile_contacts:
        var runtime := projectile_system.get_projectile(contact.projectile_instance_id)
        var result := combat_resolver.resolve_projectile_contact(contact, runtime.projectile_data if runtime != null else null, fighter_by_id(contact.attacker_id), fighter_by_id(contact.defender_id))
        if result != null: projectile_results.append(result)
    var world_results: Array[HitResult] = []
    for candidate: HitResult in world_candidates:
        var resolved := combat_resolver.resolve_world_result(candidate, fighter_by_id(candidate.attacker_id), fighter_by_id(candidate.defender_id))
        if resolved != null: world_results.append(resolved)
    var throw_result_a_to_b := combat_resolver.resolve_throw_contact(throw_a_to_b, fighter_a, fighter_b)
    var throw_result_b_to_a := combat_resolver.resolve_throw_contact(throw_b_to_a, fighter_b, fighter_a)

    # 9. Apply canonical result groups. Same-frame lethal trades remain possible because all candidates are already resolved.
    var meter_a_before_combat := fighter_a.meter.get_value(); var meter_b_before_combat := fighter_b.meter.get_value()
    for result: HitResult in strike_results:
        combat_resolver.apply_strike_result(next_frame, result, fighter_by_id(result.attacker_id), fighter_by_id(result.defender_id), _event_queue)
    for result: HitResult in projectile_results:
        if combat_resolver.apply_strike_result(next_frame, result, fighter_by_id(result.attacker_id), fighter_by_id(result.defender_id), _event_queue):
            projectile_system.mark_resolved_contact(result.source_runtime_id, result.defender_id, result.result_type)
            combat_logger.log_projectile_impact(next_frame, result.source_runtime_id, result.attacker_id, result.defender_id, result.projectile_id, result.result_type)
    for result: HitResult in world_results:
        combat_resolver.apply_strike_result(next_frame, result, fighter_by_id(result.attacker_id), fighter_by_id(result.defender_id), _event_queue)
    combat_resolver.apply_throw_result(next_frame, throw_result_a_to_b, fighter_a, fighter_b, _event_queue)
    combat_resolver.apply_throw_result(next_frame, throw_result_b_to_a, fighter_b, fighter_a, _event_queue)
    combat_logger.log_meter_gain(next_frame, fighter_a.fighter_id, fighter_a.meter.get_value() - meter_a_before_combat, fighter_a.meter.get_value())
    combat_logger.log_meter_gain(next_frame, fighter_b.fighter_id, fighter_b.meter.get_value() - meter_b_before_combat, fighter_b.meter.get_value())

    # 10. Detached cleanup after same-frame outcomes.
    var removed := projectile_system.cleanup_end_of_tick(fighter_a, fighter_b)
    for projectile: ProjectileRuntime in removed: combat_logger.log_projectile_despawn(next_frame, projectile.instance_id, projectile.owner_fighter_id, projectile.projectile_id, projectile.despawn_reason)

    # 11. KO has priority over timeout only after all same-frame results.
    var p1_ko := fighter_a.combatant.is_ko; var p2_ko := fighter_b.combatant.is_ko
    var round_ended := round_controller.evaluate_active_tick(p1_ko, p2_ko, fighter_a.combatant.hp, fighter_b.combatant.hp, frozen_at_tick_start)
    if round_ended:
        var timeout_end := not p1_ko and not p2_ko
        combat_logger.log_round_end(next_frame, round_controller.round_number, round_controller.round_result, timeout_end, fighter_a.combatant.hp, fighter_b.combatant.hp)
        if timeout_end: _event_queue.append(CombatEvent.time_up(next_frame, round_controller.round_number, round_controller.round_result))
        _event_queue.append(CombatEvent.round_ended(next_frame, round_controller.round_number, round_controller.round_result, timeout_end))
        cleanup_temporary_combat_entities()

    # 12. Move/status/mode settlement. Completion effects only execute while the round is still active.
    fighter_a.finalize_move_tick(); fighter_b.finalize_move_tick()
    if round_controller.is_round_active():
        _execute_completion_effects(fighter_a, fighter_b)
        _execute_completion_effects(fighter_b, fighter_a)
    fighter_a.status_tick(); fighter_b.status_tick()
    fighter_a.post_tick(); fighter_b.post_tick()

    # 13. Facing + sparse diagnostics.
    _update_facings()
    combat_logger.log_state_transition(next_frame, fighter_a.fighter_id, state_a_before, fighter_a.state_machine.state_name())
    combat_logger.log_state_transition(next_frame, fighter_b.fighter_id, state_b_before, fighter_b.state_machine.state_name())
    for i in range(event_start_index, _event_queue.size()): combat_logger.log_combat_event(_event_queue[i])

func _on_move_started(frame: int, fighter: Fighter, opponent: Fighter) -> void:
    _event_queue.append(CombatEvent.move_started(frame, fighter.fighter_id, fighter.move_runner.current_move_id(), fighter.move_runner.attack_instance_id))
    combat_logger.log_move_start(frame, fighter.fighter_id, fighter.move_runner.current_move_id())
    var move := fighter.move_runner.current_move
    if move != null:
        combat_resolver.effect_executor.execute_all(move.on_start_effects, fighter, opponent, temporary_entity_system, GameplayConditionEvaluator.contact_flags(opponent), STAGE_LEFT_UNITS, STAGE_RIGHT_UNITS)

func _execute_completion_effects(fighter: Fighter, opponent: Fighter) -> void:
    var effects := fighter.move_runner.consume_completion_effects()
    if not effects.is_empty():
        combat_resolver.effect_executor.execute_all(effects, fighter, opponent, temporary_entity_system, GameplayConditionEvaluator.contact_flags(opponent), STAGE_LEFT_UNITS, STAGE_RIGHT_UNITS)

func _simulate_post_round_tick(next_frame: int, input_a: InputFrame, input_b: InputFrame) -> void:
    # Authoritative inputs are already neutral. Existing physics/reactions may settle, but no new combat/spawns are built.
    fighter_a.ingest_input(input_a)
    fighter_b.ingest_input(input_b)
    fighter_a.pre_tick(next_frame)
    fighter_b.pre_tick(next_frame)
    fighter_a.movement_tick()
    fighter_b.movement_tick()
    fighter_a.movement_motor.clamp_x_to_stage()
    fighter_b.movement_motor.clamp_x_to_stage()
    collision_system.resolve_pushboxes(fighter_a, fighter_b, STAGE_LEFT_UNITS, STAGE_RIGHT_UNITS)
    fighter_a.finalize_move_tick()
    fighter_b.finalize_move_tick()
    fighter_a.status_tick()
    fighter_b.status_tick()
    fighter_a.post_tick()
    fighter_b.post_tick()
    _update_facings()

    var action := round_controller.advance_post_round()
    if action == RoundController.PostRoundAction.RESET_ROUND:
        _reset_round_runtime()
        combat_logger.log_round_reset(next_frame, round_controller.round_number)
        _event_queue.append(CombatEvent.round_started(next_frame, round_controller.round_number))
        combat_logger.log_round_start(next_frame, round_controller.round_number, round_controller.rules.id)
    elif action == RoundController.PostRoundAction.MATCH_OVER_REACHED:
        cleanup_temporary_combat_entities()
        _event_queue.append(CombatEvent.match_ended(next_frame, round_controller.match_winner, round_controller.round_number))
        combat_logger.log_match_winner(next_frame, round_controller.match_winner, round_controller.p1_round_wins, round_controller.p2_round_wins)

func _reset_round_runtime() -> void:
    cleanup_temporary_combat_entities()
    fighter_a.reset_for_round(_start_a, _start_facing_a, round_controller.rules.reset_meter_each_round, false)
    fighter_b.reset_for_round(_start_b, _start_facing_b, round_controller.rules.reset_meter_each_round, false)
    _update_facings()

func _spawn_move_projectiles(frame: int, fighter: Fighter) -> void:
    if fighter == null or fighter.move_runner.current_move == null:
        return
    var move := fighter.move_runner.current_move
    var source_move_id := move.id
    for spawn_index in fighter.move_runner.consume_projectile_spawn_indices():
        if spawn_index < 0 or spawn_index >= move.projectile_spawns.size():
            continue
        var descriptor: ProjectileSpawnData = move.projectile_spawns[spawn_index]
        if descriptor == null or not descriptor.is_valid_for_move(move.total_frames()):
            continue
        var projectile := projectile_system.spawn_from_descriptor(fighter, source_move_id, spawn_index, descriptor)
        if projectile != null:
            combat_logger.log_projectile_spawn(frame, projectile.instance_id, projectile.owner_fighter_id, projectile.projectile_id, projectile.position_units, projectile.facing)

func _authoritative_input(frame: InputFrame, required_frame: int) -> InputFrame:
    if not round_controller.is_round_active():
        return InputFrame.neutral(required_frame)
    return _normalize_frame(frame, required_frame)

func _normalize_frame(frame: InputFrame, required_frame: int) -> InputFrame:
    if frame == null:
        return InputFrame.neutral(required_frame)
    var normalized := frame.copy()
    normalized.frame_number = required_frame
    return normalized

func _update_facings() -> void:
    fighter_a.update_facing(fighter_b.movement_motor.sim_position.x)
    fighter_b.update_facing(fighter_a.movement_motor.sim_position.x)
