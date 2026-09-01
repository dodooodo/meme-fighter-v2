# Responsibility: Central deterministic HFSM transitions, action legality, meter-gated move starts, and data-defined cancel decisions.
# Owns: root/leaf state, guard posture, transition legality, state timers, one-air-attack flag, buffered action consumption.
# Does NOT own: movement integration, HP/meter reward mutation, device input polling, collision geometry, MoveData definitions.
# Dependencies: InputParser, InputBuffer, ActionMoveMap, MoveRunner, MoveRegistry, MeterComponent, Combatant, CharacterData.
class_name FighterStateMachine
extends RefCounted

enum RootState {
    GROUNDED,
    AIRBORNE,
    HIT_REACTION,
    DEAD,
}

enum State {
    IDLE,
    WALK_FORWARD,
    WALK_BACK,
    CROUCH,
    GROUND_ATTACK,
    GUARD,
    CHARGE,
    LANDING,
    JUMP,
    AIR_ATTACK,
    THROW,
    DASH_FORWARD,
    BACKSTEP,
    HITSTUN,
    BLOCKSTUN,
    THROWN,
    KNOCKDOWN,
    GETUP,
    KO,
}

enum GuardPosture {
    NONE,
    STANDING,
    CROUCHING,
}

var root_state: RootState = RootState.GROUNDED
var state: State = State.IDLE
var previous_state: State = State.IDLE
var guard_posture: GuardPosture = GuardPosture.NONE

var air_attack_available: bool = true
var landing_remaining: int = 0
var dash_move_remaining: int = 0
var dash_recovery_remaining: int = 0
var dash_elapsed_frames: int = 0
var throw_protection_remaining: int = 0
var thrown_remaining: int = 0
var knockdown_remaining: int = 0
var getup_remaining: int = 0
var pending_knockdown_frames: int = 0
var pending_getup_frames: int = 18
var throw_tech_pending: bool = false
var jump_started_this_tick: bool = false
var jump_buffer_expiry_frame: int = -1

# Generic authoritative hold/release charge-special runtime.
var charge_frames: int = 0
var charge_entry_move_id: StringName = &""
var charge_locked_facing: int = 1
var charge_early_release_requested: bool = false

enum ActionStartResult {
    NONE,
    MOVE_STARTED,
    CHARGE_STARTED,
}

# Debug-only transient diagnostic. It does not affect simulation decisions and is intentionally not snapshotted.
var last_cancel_meter_denied_target: StringName = &""
var _guard_allowed_runtime: bool = true

func reset() -> void:
    root_state = RootState.GROUNDED
    state = State.IDLE
    previous_state = State.IDLE
    guard_posture = GuardPosture.NONE
    air_attack_available = true
    landing_remaining = 0
    dash_move_remaining = 0
    dash_recovery_remaining = 0
    dash_elapsed_frames = 0
    throw_protection_remaining = 0
    thrown_remaining = 0
    knockdown_remaining = 0
    getup_remaining = 0
    pending_knockdown_frames = 0
    pending_getup_frames = 18
    throw_tech_pending = false
    jump_started_this_tick = false
    jump_buffer_expiry_frame = -1
    _clear_charge()
    last_cancel_meter_denied_target = &""

func pre_tick(
    parser: InputParser,
    input_buffer: InputBuffer,
    runner: MoveRunner,
    registry: MoveRegistry,
    meter: MeterComponent,
    combatant: Combatant,
    current_frame: int,
    data: CharacterData = null,
    mode: ModeComponent = null,
    resources: FighterResourceComponent = null,
    move_resolver: FighterMoveResolver = null,
    mechanics_runtime: FighterMechanicsRuntime = null,
    combo_scaling: ComboScalingRuntime = null,
    statuses: StatusEffectComponent = null
) -> bool:
    jump_started_this_tick = false
    last_cancel_meter_denied_target = &""
    _guard_allowed_runtime = mode == null or mode.guard_allowed()
    input_buffer.expire_if_needed(current_frame)
    if jump_buffer_expiry_frame >= 0 and current_frame > jump_buffer_expiry_frame:
        jump_buffer_expiry_frame = -1
    if parser.up_pressed and root_state != RootState.AIRBORNE and state not in [State.THROWN, State.KNOCKDOWN, State.HITSTUN, State.KO]:
        jump_buffer_expiry_frame = current_frame + 6
    if state != State.CHARGE:
        _capture_action_request(parser, input_buffer, 8 if state == State.GETUP else InputBuffer.DEFAULT_BUFFER_FRAMES)
    else:
        # Charge is a committed hold/release state; disallowed offense is never buffered for later escape.
        input_buffer.clear()

    if combatant.is_ko:
        input_buffer.clear()
        runner.interrupt()
        _clear_charge()
        jump_buffer_expiry_frame = -1
        transition_to(State.KO)
        return false
    if combatant.hitstop_remaining > 0:
        return false
    if combatant.hitstun_remaining > 0:
        input_buffer.clear()
        runner.interrupt()
        _clear_charge()
        jump_buffer_expiry_frame = -1
        transition_to(State.HITSTUN)
        return false
    if combatant.blockstun_remaining > 0:
        transition_to(State.BLOCKSTUN)
        return false

    if _tick_forced_reaction_before_control(parser, input_buffer):
        return false

    if mechanics_runtime != null and mechanics_runtime.last_stand_blocks_control():
        input_buffer.clear()
        runner.interrupt()
        if state != State.HITSTUN and state != State.KO:
            transition_to(State.IDLE)

    if state == State.CHARGE:
        return _tick_charge(parser, input_buffer, runner, registry, meter, current_frame, resources, mode, move_resolver)

    if state == State.LANDING:
        if landing_remaining > 0:
            landing_remaining -= 1
        if landing_remaining > 0:
            return false
        _settle_ground_state(parser)
        # Recovery is complete; a still-valid buffered offensive ActionIntent may execute this tick.

    if state == State.DASH_FORWARD or state == State.BACKSTEP:
        return false

    # Canonical F+H chord leniency: if Heavy was pressed up to 3F before Forward,
    # convert only the still-starting Heavy into the normal Throw. This preserves
    # immediate Heavy response while supporting the +3F side of the mobile chord.
    if state == State.GROUND_ATTACK and runner.is_running():
        if _try_convert_heavy_startup_to_throw(input_buffer, runner, registry, meter, current_frame, resources, mode, move_resolver):
            return true

    # Ground attacks may only replace themselves through MoveData cancel windows.
    if state == State.GROUND_ATTACK and runner.is_running():
        if parser.dash_forward_pressed and runner.can_cancel_to_dash():
            var dash_window := runner.active_dash_cancel_window()
            var combo_budget_ok := dash_window != null and (combo_scaling == null or combo_scaling.can_use_dash_cancel(dash_window.max_uses_per_combo))
            if combo_budget_ok and (resources == null or resources.can_spend(dash_window.movement_resource_cost_id, dash_window.movement_resource_cost_amount)):
                if resources != null and dash_window.movement_resource_cost_id != &"": resources.spend(dash_window.movement_resource_cost_id, dash_window.movement_resource_cost_amount)
                if combo_scaling != null and dash_window.max_uses_per_combo > 0: combo_scaling.record_dash_cancel()
                runner.interrupt()
                _enter_dash(data, true, mechanics_runtime, resources, statuses)
                return false
        var cancel_result := _try_start_buffered_cancel(input_buffer, runner, registry, meter, current_frame, resources, mode, move_resolver)
        return cancel_result == ActionStartResult.MOVE_STARTED

    if state in [State.AIR_ATTACK, State.THROW] and runner.is_running():
        return false

    if state == State.JUMP:
        return _try_start_air_attack(input_buffer, runner, registry, meter, current_frame, resources, mode, move_resolver)

    # Jump has movement-state priority over grounded action requests.
    if _is_ground_control_state(state) and jump_buffer_expiry_frame >= current_frame and not parser.guard_held:
        air_attack_available = true
        jump_started_this_tick = true
        jump_buffer_expiry_frame = -1
        transition_to(State.JUMP)
        return false

    if _is_ground_control_state(state):
        if parser.dash_forward_pressed:
            _enter_dash(data, true, mechanics_runtime, resources, statuses)
            return false
        if parser.backstep_pressed:
            _enter_dash(data, false, mechanics_runtime, resources, statuses)
            return false

    # Voluntary Guard remains grounded-only and has priority over every buffered offense, including Special/Ultimate.
    if _is_ground_control_state(state) and parser.guard_held and (mode == null or mode.guard_allowed()):
        _enter_guard(parser)
        return false

    if _is_ground_control_state(state) and combatant.can_start_normal_move():
        var action_result := _try_start_buffered_ground_action(input_buffer, runner, registry, meter, current_frame, resources, mode, move_resolver)
        if action_result == ActionStartResult.MOVE_STARTED:
            var move_id := runner.current_move_id()
            transition_to(State.THROW if move_id == MoveIds.GROUND_THROW else State.GROUND_ATTACK)
            return true
        if action_result == ActionStartResult.CHARGE_STARTED:
            return false

    if _is_ground_control_state(state):
        _settle_ground_state(parser)
    return false

func post_tick(
    runner: MoveRunner,
    combatant: Combatant,
    input_buffer: InputBuffer,
    parser: InputParser,
    movement_motor: MovementMotor = null,
    data: CharacterData = null
) -> void:
    if combatant.is_ko:
        input_buffer.clear()
        runner.interrupt()
        _clear_charge()
        transition_to(State.KO)
        return
    if combatant.hitstun_remaining > 0:
        input_buffer.clear()
        runner.interrupt()
        _clear_charge()
        transition_to(State.HITSTUN)
        return
    if combatant.blockstun_remaining > 0:
        transition_to(State.BLOCKSTUN)
        return

    if state == State.HITSTUN:
        if pending_knockdown_frames > 0:
            knockdown_remaining = pending_knockdown_frames
            pending_knockdown_frames = knockdown_remaining
            transition_to(State.KNOCKDOWN)
            return
        throw_protection_remaining = maxi(throw_protection_remaining, 6)
        if movement_motor != null and movement_motor.is_airborne():
            transition_to(State.JUMP)
        else:
            _settle_ground_state(parser)
        return
    if state == State.BLOCKSTUN:
        throw_protection_remaining = maxi(throw_protection_remaining, 5)
        _settle_ground_state(parser)
        return

    if movement_motor != null and movement_motor.landed_this_frame and state in [State.JUMP, State.AIR_ATTACK]:
        if state == State.AIR_ATTACK:
            runner.interrupt()
        _enter_landing(data)
        return

    if state == State.AIR_ATTACK and not runner.is_running():
        if movement_motor != null and movement_motor.is_airborne():
            transition_to(State.JUMP)
        else:
            _enter_landing(data)
        return

    if state == State.GROUND_ATTACK and not runner.is_running():
        _settle_ground_state(parser)
        return
    if state == State.THROW and not runner.is_running():
        _settle_ground_state(parser)
        return

    if state == State.DASH_FORWARD or state == State.BACKSTEP:
        _advance_dash_timers(parser)

func transition_to(next_state: State) -> bool:
    if next_state == state:
        root_state = _root_for_state(next_state)
        return true
    if not _is_transition_legal(state, next_state):
        return false
    previous_state = state
    state = next_state
    root_state = _root_for_state(next_state)
    if next_state != State.GUARD and next_state != State.BLOCKSTUN:
        guard_posture = GuardPosture.NONE
    return true

func enter_thrown(hold_frames: int, knockdown_frames: int, getup_frames: int, input_buffer: InputBuffer) -> void:
    _clear_charge()
    throw_tech_pending = false
    jump_buffer_expiry_frame = -1
    thrown_remaining = maxi(0, hold_frames)
    pending_knockdown_frames = maxi(0, knockdown_frames)
    pending_getup_frames = maxi(1, getup_frames)
    input_buffer.clear()
    transition_to(State.THROWN)

func schedule_knockdown_after_hitstun(knockdown_frames: int, getup_frames: int) -> void:
    pending_knockdown_frames = maxi(1, knockdown_frames)
    pending_getup_frames = maxi(1, getup_frames)

func clear_pending_knockdown() -> void:
    pending_knockdown_frames = 0
    pending_getup_frames = 18

func enter_knockdown(knockdown_frames: int, getup_frames: int, input_buffer: InputBuffer) -> void:
    _clear_charge()
    throw_tech_pending = false
    jump_buffer_expiry_frame = -1
    thrown_remaining = 0
    knockdown_remaining = maxi(1, knockdown_frames)
    pending_knockdown_frames = knockdown_remaining
    pending_getup_frames = maxi(1, getup_frames)
    input_buffer.clear()
    transition_to(State.KNOCKDOWN)

func enter_throw_tech_window(input_buffer: InputBuffer) -> void:
    _clear_charge()
    jump_buffer_expiry_frame = -1
    throw_tech_pending = true
    thrown_remaining = 0
    pending_knockdown_frames = 0
    input_buffer.clear()
    transition_to(State.THROWN)

func exit_throw_tech_window(parser: InputParser) -> void:
    throw_tech_pending = false
    thrown_remaining = 0
    pending_knockdown_frames = 0
    _settle_ground_state(parser)

func exit_throw_after_tech(parser: InputParser) -> void:
    throw_tech_pending = false
    thrown_remaining = 0
    pending_knockdown_frames = 0
    if state == State.THROW:
        _settle_ground_state(parser)

func tick_universal_protection(frozen_by_hitstop: bool) -> void:
    if frozen_by_hitstop:
        return
    if throw_protection_remaining > 0:
        throw_protection_remaining -= 1

func is_throw_protected() -> bool:
    return throw_protection_remaining > 0

func has_backstep_throw_invulnerability() -> bool:
    # Canonical Backstep: grounded, strike-vulnerable, Throw-invulnerable on F1–6 only.
    return state == State.BACKSTEP and dash_elapsed_frames < 6

func is_guarding() -> bool:
    return state == State.GUARD and guard_posture != GuardPosture.NONE

func is_throwable() -> bool:
    # Canonical grounded throwability: startup/recovery can be thrown, while hit/block reactions,
    # wakeup and airborne states are protected by their explicit rules. Active Strike vs Throw is
    # settled later by SameTickArbitrator from the shared pre-apply state.
    return state in [
        State.IDLE,
        State.WALK_FORWARD,
        State.WALK_BACK,
        State.CROUCH,
        State.GUARD,
        State.CHARGE,
        State.DASH_FORWARD,
        State.BACKSTEP,
        State.LANDING,
        State.GROUND_ATTACK,
        State.THROW,
    ]

func is_strike_target() -> bool:
    # GETUP protection is a temporary greybox rule. THROWN/KNOCKDOWN are also non-OTG in this milestone.
    return state not in [State.GETUP, State.THROWN, State.KNOCKDOWN, State.KO]

func is_facing_locked(runner: MoveRunner) -> bool:
    if state == State.CHARGE:
        return true
    return runner.is_running() and state in [State.GROUND_ATTACK, State.AIR_ATTACK, State.THROW]

func is_grounded_state() -> bool:
    return root_state == RootState.GROUNDED

func guard_posture_name() -> String:
    return GuardPosture.keys()[guard_posture]

func state_name() -> String:
    return State.keys()[state]

func root_state_name() -> String:
    return RootState.keys()[root_state]

func _capture_action_request(parser: InputParser, input_buffer: InputBuffer, window_frames: int = InputBuffer.DEFAULT_BUFFER_FRAMES) -> void:
    var intent := parser.action_pressed_intent()
    if intent != null:
        input_buffer.buffer_intent(intent, window_frames)


func _try_convert_heavy_startup_to_throw(
    input_buffer: InputBuffer,
    runner: MoveRunner,
    registry: MoveRegistry,
    meter: MeterComponent,
    current_frame: int,
    resources: FighterResourceComponent = null,
    mode: ModeComponent = null,
    move_resolver: FighterMoveResolver = null
) -> bool:
    var intent := input_buffer.peek_intent(current_frame)
    if intent == null or ActionMoveMap.ground_move_id_for_intent(intent) != MoveIds.GROUND_THROW:
        return false
    var resolved_heavy := move_resolver.resolve(MoveIds.STAND_HEAVY, mode, resources) if move_resolver != null else (mode.resolve_move_id(MoveIds.STAND_HEAVY, resources) if mode != null else MoveIds.STAND_HEAVY)
    if runner.current_move_id() != resolved_heavy or runner.phase() != &"STARTUP" or runner.move_frame > 3:
        return false
    var throw_id := move_resolver.resolve(MoveIds.GROUND_THROW, mode, resources) if move_resolver != null else (mode.resolve_move_id(MoveIds.GROUND_THROW, resources) if mode != null else MoveIds.GROUND_THROW)
    var throw_move := registry.get_move(throw_id)
    if throw_move == null or not _can_pay_move(throw_move, meter, resources):
        return false
    runner.interrupt()
    if not runner.start_move(throw_move):
        return false
    _pay_move(throw_move, meter, resources, runner)
    input_buffer.consume_intent(current_frame)
    transition_to(State.THROW)
    return true

func _try_start_buffered_ground_action(
    input_buffer: InputBuffer,
    runner: MoveRunner,
    registry: MoveRegistry,
    meter: MeterComponent,
    current_frame: int,
    resources: FighterResourceComponent = null,
    mode: ModeComponent = null,
    move_resolver: FighterMoveResolver = null
) -> ActionStartResult:
    var intent := input_buffer.peek_intent(current_frame)
    if intent == null:
        return ActionStartResult.NONE
    var canonical_id := ActionMoveMap.ground_move_id_for_intent(intent)
    if canonical_id == &"":
        input_buffer.clear(); return ActionStartResult.NONE
    var move_id := move_resolver.resolve(canonical_id, mode, resources) if move_resolver != null else (mode.resolve_move_id(canonical_id, resources) if mode != null else canonical_id)
    var move := registry.get_move(move_id)
    if move == null:
        input_buffer.clear(); return ActionStartResult.NONE
    if move.charge_special_data != null:
        if not move.charge_special_data.is_valid(): input_buffer.clear(); return ActionStartResult.NONE
        _enter_charge(move_id, intent.facing_at_request); input_buffer.consume_intent(current_frame); return ActionStartResult.CHARGE_STARTED
    if not _can_pay_move(move, meter, resources): return ActionStartResult.NONE
    if not runner.start_move(move): return ActionStartResult.NONE
    _pay_move(move, meter, resources, runner); input_buffer.consume_intent(current_frame)
    return ActionStartResult.MOVE_STARTED

func _try_start_buffered_cancel(
    input_buffer: InputBuffer,
    runner: MoveRunner,
    registry: MoveRegistry,
    meter: MeterComponent,
    current_frame: int,
    resources: FighterResourceComponent = null,
    mode: ModeComponent = null,
    move_resolver: FighterMoveResolver = null
) -> ActionStartResult:
    var intent := input_buffer.peek_intent(current_frame)
    if intent == null: return ActionStartResult.NONE
    var canonical_id := ActionMoveMap.ground_move_id_for_intent(intent)
    var target_move_id := move_resolver.resolve(canonical_id, mode, resources) if move_resolver != null else (mode.resolve_move_id(canonical_id, resources) if mode != null else canonical_id)
    if target_move_id == &"" or not runner.can_cancel_to(target_move_id, resources): return ActionStartResult.NONE
    var target_move := registry.get_move(target_move_id)
    if target_move == null: input_buffer.clear(); return ActionStartResult.NONE
    if target_move.charge_special_data != null:
        if not target_move.charge_special_data.is_valid(): input_buffer.clear(); return ActionStartResult.NONE
        runner.interrupt(); _enter_charge(target_move_id, intent.facing_at_request); input_buffer.consume_intent(current_frame); return ActionStartResult.CHARGE_STARTED
    if not _can_pay_move(target_move, meter, resources):
        last_cancel_meter_denied_target = target_move_id; return ActionStartResult.NONE
    if not runner.start_cancel(target_move): return ActionStartResult.NONE
    _pay_move(target_move, meter, resources, runner); input_buffer.consume_intent(current_frame)
    return ActionStartResult.MOVE_STARTED

func _enter_charge(entry_move_id: StringName, facing_at_request: int) -> void:
    charge_frames = 1
    charge_entry_move_id = entry_move_id
    charge_locked_facing = -1 if facing_at_request < 0 else 1
    charge_early_release_requested = false
    transition_to(State.CHARGE)

func _tick_charge(
    parser: InputParser,
    input_buffer: InputBuffer,
    runner: MoveRunner,
    registry: MoveRegistry,
    meter: MeterComponent,
    _current_frame: int,
    resources: FighterResourceComponent = null,
    _mode: ModeComponent = null,
    _move_resolver: FighterMoveResolver = null
) -> bool:
    input_buffer.clear()
    var entry_move := registry.get_move(charge_entry_move_id)
    if entry_move == null or entry_move.charge_special_data == null or not entry_move.charge_special_data.is_valid():
        _clear_charge(); _settle_ground_state(parser); return false
    var charge_data := entry_move.charge_special_data
    var release_requested := charge_early_release_requested or parser.special_released or not parser.special_held
    if release_requested and charge_frames < charge_data.minimum_level_1_frames:
        # A 1–2F mobile tap is remembered rather than dropped. The charge remains committed and
        # deterministically releases Lv1 on the first legal 3F charge tick.
        charge_early_release_requested = true
        charge_frames += 1
        if charge_frames < charge_data.minimum_level_1_frames:
            return false
        release_requested = true
    if release_requested:
        var target_id := charge_data.move_id_for_charge_frames(charge_frames)
        var target_move := registry.get_move(target_id)
        if target_move == null or not _can_pay_move(target_move, meter, resources):
            _clear_charge(); _settle_ground_state(parser); return false
        if not runner.start_move(target_move): return false
        _pay_move(target_move, meter, resources, runner)
        _clear_charge(); transition_to(State.GROUND_ATTACK); return true
    charge_frames += 1
    return false

func _clear_charge() -> void:
    charge_frames = 0
    charge_entry_move_id = &""
    charge_locked_facing = 1
    charge_early_release_requested = false

func charge_level(registry: MoveRegistry) -> int:
    if state != State.CHARGE or registry == null:
        return 0
    var entry_move := registry.get_move(charge_entry_move_id)
    if entry_move == null or entry_move.charge_special_data == null:
        return 0
    return entry_move.charge_special_data.level_for_charge_frames(charge_frames)

func _try_start_air_attack(
    input_buffer: InputBuffer,
    runner: MoveRunner,
    registry: MoveRegistry,
    meter: MeterComponent,
    current_frame: int,
    resources: FighterResourceComponent = null,
    mode: ModeComponent = null,
    move_resolver: FighterMoveResolver = null
) -> bool:
    if not air_attack_available: return false
    var intent := input_buffer.peek_intent(current_frame)
    if intent == null: return false
    var canonical_id := ActionMoveMap.air_move_id_for_intent(intent)
    if canonical_id == &"": input_buffer.clear(); return false
    var move_id := move_resolver.resolve(canonical_id, mode, resources) if move_resolver != null else (mode.resolve_move_id(canonical_id, resources) if mode != null else canonical_id)
    var move := registry.get_move(move_id)
    if move == null: input_buffer.clear(); return false
    if not _can_pay_move(move, meter, resources) or not runner.start_move(move): return false
    _pay_move(move, meter, resources, runner); input_buffer.consume_intent(current_frame)
    air_attack_available = false; transition_to(State.AIR_ATTACK); return true

func _enter_guard(parser: InputParser) -> void:
    if not _guard_allowed_runtime:
        transition_to(State.IDLE)
        return
    guard_posture = GuardPosture.CROUCHING if parser.down_held else GuardPosture.STANDING
    transition_to(State.GUARD)

func _enter_landing(data: CharacterData) -> void:
    air_attack_available = true
    landing_remaining = data.landing_recovery_frames if data != null else 3
    transition_to(State.LANDING)

func _enter_dash(data: CharacterData, forward: bool, mechanics_runtime: FighterMechanicsRuntime = null, resources: FighterResourceComponent = null, statuses: StatusEffectComponent = null) -> void:
    if data == null: return
    dash_move_remaining = data.dash_move_frames if forward else data.backstep_move_frames
    dash_elapsed_frames = 0
    dash_recovery_remaining = (resources.dash_recovery_frames(data.dash_recovery_frames) if forward and resources != null else data.dash_recovery_frames) if forward else data.backstep_recovery_frames
    if not forward and mechanics_runtime != null and statuses != null:
        var panic_id := mechanics_runtime.panic_status_id()
        # This transition is the committed, legal Backstep boundary. Status data
        # opt-in through CharacterMechanicsData; no character identity is needed.
        if panic_id != &"" and statuses.has_status(panic_id):
            statuses.remove(panic_id)
            dash_recovery_remaining = maxi(0, dash_recovery_remaining - mechanics_runtime.panic_backstep_startup_reduction())
            mechanics_runtime.activate_panic_backstep(dash_move_remaining + dash_recovery_remaining)
    transition_to(State.DASH_FORWARD if forward else State.BACKSTEP)

func _advance_dash_timers(parser: InputParser) -> void:
    dash_elapsed_frames += 1
    if dash_move_remaining > 0:
        dash_move_remaining -= 1
        return
    if dash_recovery_remaining > 0:
        dash_recovery_remaining -= 1
        if dash_recovery_remaining > 0:
            return
    dash_move_remaining = 0
    dash_recovery_remaining = 0
    dash_elapsed_frames = 0
    _settle_ground_state(parser)

func _tick_forced_reaction_before_control(parser: InputParser, input_buffer: InputBuffer) -> bool:
    if state == State.THROWN:
        input_buffer.clear()
        if throw_tech_pending:
            return true
        if thrown_remaining > 0:
            thrown_remaining -= 1
        if thrown_remaining <= 0:
            knockdown_remaining = pending_knockdown_frames
            input_buffer.clear()
            transition_to(State.KNOCKDOWN)
        return true
    if state == State.KNOCKDOWN:
        input_buffer.clear()
        if knockdown_remaining > 0:
            knockdown_remaining -= 1
        if knockdown_remaining <= 0:
            getup_remaining = pending_getup_frames
            input_buffer.clear()
            transition_to(State.GETUP)
        return true
    if state == State.GETUP:
        # Canonical wakeup buffer: offensive requests made during the final 8F survive until control returns.
        if getup_remaining > 0:
            getup_remaining -= 1
        if getup_remaining <= 0:
            getup_remaining = 0
            _complete_getup(parser)
        return true
    return false

func _complete_getup(parser: InputParser) -> void:
    if parser.guard_held:
        _enter_guard(parser)
    elif parser.down_held:
        transition_to(State.CROUCH)
    else:
        transition_to(State.IDLE)

func _settle_ground_state(parser: InputParser) -> void:
    if parser.guard_held:
        _enter_guard(parser)
    elif parser.down_held:
        transition_to(State.CROUCH)
    elif parser.forward_held:
        transition_to(State.WALK_FORWARD)
    elif parser.back_held:
        transition_to(State.WALK_BACK)
    else:
        transition_to(State.IDLE)

func has_actionable_control() -> bool:
    return _is_ground_control_state(state)

func _is_ground_control_state(value: State) -> bool:
    return value in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD]

func _is_transition_legal(from_state: State, to_state: State) -> bool:
    if to_state == State.KO:
        return true
    if to_state in [State.HITSTUN, State.BLOCKSTUN]:
        return from_state != State.KO
    if to_state == State.THROWN:
        return from_state != State.KO
    match from_state:
        State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD:
            return to_state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GROUND_ATTACK, State.GUARD, State.CHARGE, State.JUMP, State.THROW, State.DASH_FORWARD, State.BACKSTEP]
        State.LANDING:
            return to_state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD, State.GROUND_ATTACK, State.THROW]
        State.JUMP:
            return to_state in [State.JUMP, State.AIR_ATTACK, State.LANDING]
        State.AIR_ATTACK:
            return to_state in [State.JUMP, State.LANDING]
        State.GROUND_ATTACK:
            return to_state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD, State.CHARGE, State.DASH_FORWARD]
        State.THROW:
            return to_state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD, State.CHARGE]
        State.CHARGE:
            return to_state in [State.GROUND_ATTACK, State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD]
        State.DASH_FORWARD, State.BACKSTEP:
            return to_state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD]
        State.HITSTUN:
            return to_state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD, State.JUMP]
        State.BLOCKSTUN:
            return to_state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACK, State.CROUCH, State.GUARD]
        State.THROWN:
            return to_state == State.KNOCKDOWN
        State.KNOCKDOWN:
            return to_state == State.GETUP
        State.GETUP:
            return to_state in [State.IDLE, State.CROUCH, State.GUARD]
        State.KO:
            return false
    return false

func _root_for_state(value: State) -> RootState:
    match value:
        State.JUMP, State.AIR_ATTACK:
            return RootState.AIRBORNE
        State.HITSTUN, State.BLOCKSTUN, State.THROWN, State.KNOCKDOWN, State.GETUP:
            return RootState.HIT_REACTION
        State.KO:
            return RootState.DEAD
        _:
            return RootState.GROUNDED

func _can_pay_move(move: MoveData, meter: MeterComponent, resources: FighterResourceComponent) -> bool:
    if move == null or not meter.can_spend(move.meter_cost): return false
    if move.resource_cost_id != &"" and move.resource_cost_amount > 0:
        return resources != null and resources.can_spend(move.resource_cost_id, move.resource_cost_amount)
    return true

func _pay_move(move: MoveData, meter: MeterComponent, resources: FighterResourceComponent, runner: MoveRunner) -> void:
    meter.spend(move.meter_cost)
    if move.resource_cost_id != &"" and move.resource_cost_amount > 0 and resources != null:
        resources.spend(move.resource_cost_id, move.resource_cost_amount)
    if move.activation_resource_cashout_id != &"" and resources != null:
        runner.capture_activation_resource(move.activation_resource_cashout_id, resources.get_value(move.activation_resource_cashout_id))
        resources.cash_out(move.activation_resource_cashout_id)
