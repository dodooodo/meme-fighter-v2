# Responsibility: Fighter composition root / orchestrator for simulation components.
# Owns: component wiring and fighter identity/data reference.
# Does NOT own: jump physics, throw geometry, dash recognition, forced-reaction timer logic, snapshot serialization, presentation.
# Dependencies: Input*, FighterStateMachine, MovementMotor, MoveRunner/Registry, MeterComponent, Combatant, HitboxOwner.
class_name Fighter
extends RefCounted

var fighter_id: int = 0
var data: CharacterData
var input_source: InputSource
var input_history: InputHistory = InputHistory.new(60)
var input_parser: InputParser = InputParser.new()
var input_buffer: InputBuffer = InputBuffer.new()
var state_machine: FighterStateMachine = FighterStateMachine.new()
var movement_motor: MovementMotor = MovementMotor.new()
var move_runner: MoveRunner = MoveRunner.new()
var move_registry: MoveRegistry = MoveRegistry.new()
var meter: MeterComponent = MeterComponent.new()
var combatant: Combatant = Combatant.new()
var hitbox_owner: HitboxOwner = HitboxOwner.new()
var resources: FighterResourceComponent = FighterResourceComponent.new()
var statuses: StatusEffectComponent = StatusEffectComponent.new()
var mode: ModeComponent = ModeComponent.new()
var defense_modifiers: DefenseModifierComponent = DefenseModifierComponent.new()
var mechanics_runtime: FighterMechanicsRuntime = FighterMechanicsRuntime.new()
var move_resolver: FighterMoveResolver = FighterMoveResolver.new()
var combo_scaling: ComboScalingRuntime = ComboScalingRuntime.new()

func configure(
    p_fighter_id: int,
    p_data: CharacterData,
    start_position_units: Vector2i,
    stage_left_units: int,
    stage_right_units: int,
    ground_y_units: int,
    p_input_source: InputSource = null
) -> void:
    fighter_id = p_fighter_id
    data = p_data
    input_source = p_input_source
    input_history.clear()
    input_parser = InputParser.new()
    input_buffer = InputBuffer.new()
    state_machine.reset()
    move_runner = MoveRunner.new()
    move_runner.configure(fighter_id)
    move_registry = MoveRegistry.new()
    if not move_registry.configure(data.move_set):
        push_error("Invalid MoveSet for %s: %s" % [String(data.id), str(move_registry.validation_errors())])
    meter = MeterComponent.new()
    combatant.configure(data.max_hp)
    hitbox_owner.configure(data)
    resources.configure(data.mechanics)
    statuses.configure(data.mechanics)
    mode.configure(data.mechanics)
    defense_modifiers.configure(data.mechanics)
    mechanics_runtime.configure(data.mechanics)
    move_resolver = FighterMoveResolver.new()
    combo_scaling = ComboScalingRuntime.new()
    movement_motor.configure(start_position_units, stage_left_units, stage_right_units, ground_y_units)


func reset_for_round(
    start_position_units: Vector2i,
    start_facing: int,
    reset_meter_value: bool = true,
    reset_instance_serial: bool = false
) -> void:
    # Keep immutable CharacterData/MoveSet/MoveRegistry wiring; reset only Fighter-owned mutable runtime.
    input_history.clear()
    input_parser = InputParser.new()
    input_buffer = InputBuffer.new()
    if input_source != null:
        input_source.reset()
    state_machine.reset()
    move_runner.reset_runtime(reset_instance_serial)
    combatant.reset()
    if reset_meter_value:
        meter.reset()
    hitbox_owner.reset_runtime()
    resources.reset_for_round()
    statuses.reset_for_round()
    mode.reset_for_round()
    mechanics_runtime.reset_for_round()
    combo_scaling.reset()
    movement_motor.configure(
        start_position_units,
        movement_motor.stage_left_units,
        movement_motor.stage_right_units,
        movement_motor.ground_y_units
    )
    movement_motor.facing = -1 if start_facing < 0 else 1

func sample_input(frame_number: int) -> InputFrame:
    if input_source == null:
        return InputFrame.neutral(frame_number)
    return input_source.sample(frame_number)

func ingest_input(frame: InputFrame) -> void:
    input_history.push(frame)
    input_parser.update(frame, movement_motor.facing, input_history)
    mechanics_runtime.observe_control_context(state_machine, input_parser)

func pre_tick(current_frame: int) -> bool:
    # Panic Exit is consumed only by the state machine when a Backstep actually
    # begins. Input recognition alone must not spend a pending optional escape.
    var started := state_machine.pre_tick(input_parser, input_buffer, move_runner, move_registry, meter, combatant, current_frame, data, mode, resources, move_resolver, mechanics_runtime, combo_scaling, statuses)
    if started:
        hitbox_owner.begin_attack_instance(move_runner.attack_instance_id)
        mechanics_runtime.begin_move_defenses(move_runner.current_move, move_runner.attack_instance_id)
        if state_machine.state == FighterStateMachine.State.AIR_ATTACK:
            mechanics_runtime.record_air_attack_context(movement_motor)
    if state_machine.jump_started_this_tick:
        movement_motor.begin_jump(data)
    return started

func movement_tick() -> void:
    movement_motor.tick(state_machine, combatant, data, input_parser, move_runner, statuses, mode, mechanics_runtime, resources)

func finalize_move_tick() -> void:
    move_runner.finalize_tick(combatant.hitstop_remaining > 0)

func status_tick() -> void:
    var frozen := combatant.hitstop_remaining > 0
    combatant.tick_statuses()
    state_machine.tick_universal_protection(frozen)
    statuses.tick(frozen)
    mechanics_runtime.tick(frozen)
    var was_last_stand := mechanics_runtime.last_stand_active
    mode.tick(frozen, resources)
    var mode_exit_move_id := mode.last_expired_exit_move_id
    sync_mechanics_from_mode()
    if mode_exit_move_id != &"" and not move_runner.is_running():
        var exit_move := move_registry.get_move(mode_exit_move_id)
        if exit_move != null:
            move_runner.start_move(exit_move)
            hitbox_owner.begin_attack_instance(move_runner.attack_instance_id)
            mechanics_runtime.begin_move_defenses(exit_move, move_runner.attack_instance_id)
            state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    if was_last_stand and not mechanics_runtime.last_stand_active and data.mechanics != null:
        var resource_id := data.mechanics.last_stand_resolve_resource_id
        var level := resources.get_value(resource_id)
        if level >= 0 and level < data.mechanics.last_stand_expiry_move_ids.size():
            var move_id := data.mechanics.last_stand_expiry_move_ids[level]
            var expiry_move := move_registry.get_move(move_id)
            if expiry_move != null and not move_runner.is_running():
                move_runner.start_move(expiry_move)
                hitbox_owner.begin_attack_instance(move_runner.attack_instance_id)
                mechanics_runtime.begin_move_defenses(expiry_move, move_runner.attack_instance_id)
                state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
        resources.set_value(resource_id, 0)

func post_tick() -> void:
    state_machine.post_tick(move_runner, combatant, input_buffer, input_parser, movement_motor, data)

func update_facing(opponent_x_units: int) -> void:
    if state_machine.is_facing_locked(move_runner):
        return
    movement_motor.update_facing(opponent_x_units)

func position_pixels() -> Vector2:
    return movement_motor.position_pixels()

# Stable read-only boundary for external observers. Every value derives from an
# existing authoritative component; no state is cached or duplicated here.
func is_grounded() -> bool:
    return not movement_motor.is_airborne()

func is_airborne() -> bool:
    return movement_motor.is_airborne()

func has_status(id: StringName) -> bool:
    return statuses.has_status(id)

func status_remaining(id: StringName) -> int:
    return statuses.remaining_frames(id)

func get_resource_value(id: StringName) -> int:
    return resources.get_value(id)

func get_active_mode_id() -> StringName:
    return mode.active_mode_id

func get_mode_remaining_frames() -> int:
    return mode.remaining_frames

func has_move(id: StringName) -> bool:
    return move_registry.has_move(id)

func has_charge_special() -> bool:
    var move := move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    return move != null and move.charge_special_data != null

func can_afford_move(id: StringName) -> bool:
    var move := move_registry.get_move(id)
    return move != null and meter.can_spend(move.meter_cost)

func capture_combat_read() -> Dictionary:
    return FighterReadView.capture(self)

func debug_summary(current_frame: int) -> String:
    var move_name := String(move_runner.current_move_id()) if move_runner.is_running() else "-"
    var phase_name := String(move_runner.phase())
    var buffer_name := input_buffer.buffered_action_name(current_frame)
    var buffered_intent := input_buffer.peek_intent(current_frame)
    var buffer_detail := "NONE"
    if buffered_intent != null:
        buffer_detail = "%s@F%d dir=(%d,%d) fwd=%s back=%s exp=%d" % [
            buffer_name,
            buffered_intent.source_frame,
            buffered_intent.direction_x,
            buffered_intent.direction_y,
            str(buffered_intent.forward_held),
            str(buffered_intent.back_held),
            input_buffer.expiry_frame(),
        ]
    var cancel_targets: Array[StringName] = move_runner.active_cancel_targets()
    var cancel_target_names: PackedStringArray = []
    for target: StringName in cancel_targets:
        cancel_target_names.append(String(target))
    var cancel_summary := ",".join(cancel_target_names) if not cancel_target_names.is_empty() else "-"
    var last_result := "NONE"
    if combatant.last_result_type >= 0 and combatant.last_result_type < HitResult.ResultType.size():
        last_result = HitResult.ResultType.keys()[combatant.last_result_type]
    var charge_level := state_machine.charge_level(move_registry)
    var charge_summary := "Lv%d/%dF" % [charge_level, state_machine.charge_frames] if charge_level > 0 else "-"
    return "P%d Character=%s state=%s root=%s face=%d pos=(%d,%d) vel=(%d,%d) move=%s mf=%d phase=%s conn=%s cancel=%s targets=%s meter=%d/100 charge=%s airAtk=%s hp=%d hs=%d bs=%d stop=%d guard=%s dash=(%d/%d) thrown=%d kd=%d getup=%d buf=%s last=%s" % [
        fighter_id,
        String(data.id) if data != null else "<none>",
        state_machine.state_name(),
        state_machine.root_state_name(),
        movement_motor.facing,
        movement_motor.sim_position.x,
        movement_motor.sim_position.y,
        movement_motor.velocity_units.x,
        movement_motor.velocity_units.y,
        move_name,
        move_runner.move_frame,
        phase_name,
        move_runner.connection_name(),
        "active" if move_runner.cancel_window_active() else "inactive",
        cancel_summary,
        meter.get_value(),
        charge_summary,
        str(state_machine.air_attack_available),
        combatant.hp,
        combatant.hitstun_remaining,
        combatant.blockstun_remaining,
        combatant.hitstop_remaining,
        state_machine.guard_posture_name(),
        state_machine.dash_move_remaining,
        state_machine.dash_recovery_remaining,
        state_machine.thrown_remaining,
        state_machine.knockdown_remaining,
        state_machine.getup_remaining,
        buffer_detail,
        last_result,
    ] + " combo=%d@%d%% dmg=%d dc=%d" % [combo_scaling.hit_count, combo_scaling.current_scale_percent, combo_scaling.combo_damage, combo_scaling.dash_cancel_count]

func enter_forced_stand(frames: int) -> void:
    move_runner.interrupt()
    mechanics_runtime.forced_stand_remaining = maxi(1, frames)
    combatant.hitstun_remaining = maxi(combatant.hitstun_remaining, maxi(1, frames))
    combatant.knockback_velocity_y_units = 0
    movement_motor.sim_position.y = movement_motor.ground_y_units
    movement_motor.velocity_units.y = 0
    state_machine.transition_to(FighterStateMachine.State.HITSTUN)

func sync_mechanics_from_mode() -> void:
    mechanics_runtime.last_stand_active = data.mechanics != null and data.mechanics.last_stand_mode_id != &"" and mode.active_mode_id == data.mechanics.last_stand_mode_id
    if mechanics_runtime.last_stand_active:
        mechanics_runtime.last_stand_mode_serial = mode.mode_serial
