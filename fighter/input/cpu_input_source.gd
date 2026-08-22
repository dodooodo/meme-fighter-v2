# Responsibility: Deterministic rules-based playtest CPU -> canonical InputFrame only.
# Owns: read-only decision policy and action edge composition.
# Does NOT own: Fighter mutation, HP, Meter, MoveRunner starts, state transitions, collision, damage, wall-clock randomness.
class_name CpuInputSource
extends InputSource

const REACTION_INTERVAL_FRAMES: int = 8
const CLOSE_DISTANCE_UNITS: int = 12000
const MID_DISTANCE_UNITS: int = 26000
const DEFAULT_SEED: int = 0x28491

var _own: Fighter = null
var _opponent: Fighter = null
var _simulation: BattleSimulation = null
var _previous_held_bits: int = 0
var _seed: int = DEFAULT_SEED
var _decision_block: int = -1
var _current_decision: StringName = &"idle"
var _charge_target_frames_planned: int = 0

func bind_context(own_fighter: Fighter, opponent_fighter: Fighter, simulation: BattleSimulation) -> bool:
    if own_fighter == null or opponent_fighter == null or simulation == null:
        return false
    _own = own_fighter
    _opponent = opponent_fighter
    _simulation = simulation
    return true

func set_fixed_seed(value: int) -> void:
    _seed = value

func sample(frame_number: int) -> InputFrame:
    if _own == null or _opponent == null or _simulation == null:
        return _compose_frame(frame_number, 0, 0, 0)

    if _own.state_machine.state == FighterStateMachine.State.CHARGE:
        return _sample_charge(frame_number)

    if _own.combatant.is_ko or _own.combatant.hitstun_remaining > 0 or _own.combatant.blockstun_remaining > 0:
        return _compose_frame(frame_number, 0, 0, 0)
    if _own.state_machine.state in [
        FighterStateMachine.State.THROWN,
        FighterStateMachine.State.KNOCKDOWN,
        FighterStateMachine.State.GETUP,
        FighterStateMachine.State.LANDING,
    ]:
        return _compose_frame(frame_number, 0, 0, 0)

    _charge_target_frames_planned = 0
    var block := maxi(0, int((frame_number - 1) / REACTION_INTERVAL_FRAMES))
    var offset := maxi(0, (frame_number - 1) % REACTION_INTERVAL_FRAMES)
    var distance := absi(_opponent.movement_motor.sim_position.x - _own.movement_motor.sim_position.x)
    if block != _decision_block:
        _decision_block = block
        _current_decision = _choose_decision(distance, _roll(block, 0))
    return _frame_for_decision(frame_number, block, offset, distance, _current_decision)

func reset() -> void:
    _previous_held_bits = 0
    _decision_block = -1
    _current_decision = &"idle"
    _charge_target_frames_planned = 0

func _sample_charge(frame_number: int) -> InputFrame:
    var charge_data := _charge_data()
    if charge_data == null:
        return _compose_frame(frame_number, 0, 0, 0)
    if _charge_target_frames_planned <= 0:
        var distance := absi(_opponent.movement_motor.sim_position.x - _own.movement_motor.sim_position.x)
        _charge_target_frames_planned = _charge_target_frames(distance)
    var held := InputFrame.InputButton.SPECIAL if _own.state_machine.charge_frames < _charge_target_frames_planned else 0
    return _compose_frame(frame_number, 0, 0, held)

func _choose_decision(distance: int, roll: int) -> StringName:
    var opponent_attacking := _opponent.move_runner.is_running()
    var opponent_guarding := _opponent.state_machine.is_guarding()
    var can_ultimate := _can_use_ultimate()

    # Reaction-limited defensive read only observes already-established simulation state.
    if opponent_attacking and distance <= MID_DISTANCE_UNITS and roll < 38:
        return &"guard_low" if _opponent.move_runner.current_move != null and _opponent.move_runner.current_move.hit_level == MoveData.HitLevel.LOW else &"guard"

    if distance > MID_DISTANCE_UNITS:
        if can_ultimate and roll < 8:
            return &"ultimate"
        if _has_special() and roll < 34:
            return &"special"
        if roll < 76:
            return &"walk_forward"
        if roll < 86:
            return &"jump"
        if roll < 92:
            return &"dash"
        return &"walk_back"

    if distance > CLOSE_DISTANCE_UNITS:
        if can_ultimate and (_opponent.combatant.hitstun_remaining > 0 or (_opponent.move_runner.is_running() and _opponent.move_runner.phase() == &"RECOVERY")) and roll < 28:
            return &"ultimate"
        if _has_special() and roll < 18:
            return &"special"
        if roll < 35:
            return &"heavy"
        if roll < 49:
            return &"low"
        if roll < 62:
            return &"walk_forward"
        if roll < 72:
            return &"walk_back"
        if roll < 78:
            return &"crouch"
        if roll < 88:
            return &"jump"
        if roll < 94:
            return &"dash"
        return &"guard"

    if opponent_guarding and roll < 32:
        return &"throw"
    if can_ultimate and _opponent.combatant.hitstun_remaining > 0 and roll < 18:
        return &"ultimate"
    if roll < 34:
        return &"light"
    if roll < 50:
        return &"heavy"
    if roll < 63:
        return &"low"
    if roll < 76:
        return &"guard"
    if roll < 82:
        return &"guard_low"
    if roll < 87:
        return &"crouch"
    if roll < 93:
        return &"walk_back"
    if _has_special():
        return &"special"
    return &"light"

func _frame_for_decision(frame_number: int, block: int, offset: int, _distance: int, decision: StringName) -> InputFrame:
    var direction_x := 0
    var direction_y := 0
    var held := 0
    var facing := -1 if _own.movement_motor.facing < 0 else 1
    match decision:
        &"walk_forward":
            direction_x = facing
        &"walk_back":
            direction_x = -facing
        &"guard":
            held = InputFrame.InputButton.GUARD
        &"guard_low":
            direction_y = -1
            held = InputFrame.InputButton.GUARD
        &"crouch":
            direction_y = -1
        &"light":
            if offset == 0:
                held = InputFrame.InputButton.LIGHT
        &"heavy":
            if offset == 0:
                held = InputFrame.InputButton.HEAVY
        &"low":
            if offset == 0:
                direction_y = -1
                held = InputFrame.InputButton.LIGHT
        &"throw":
            if offset == 0:
                direction_x = facing
                held = InputFrame.InputButton.HEAVY
        &"jump":
            if offset == 0:
                direction_y = 1
        &"special":
            if offset == 0:
                held = InputFrame.InputButton.SPECIAL
        &"ultimate":
            if offset == 0 and _can_use_ultimate():
                held = InputFrame.InputButton.ULTIMATE
        &"dash":
            if offset == 0 or offset == 2:
                direction_x = facing
        _:
            pass
    return _compose_frame(frame_number, direction_x, direction_y, held)

func _compose_frame(frame_number: int, direction_x: int, direction_y: int, held: int) -> InputFrame:
    var pressed := held & ~_previous_held_bits
    var released := _previous_held_bits & ~held
    _previous_held_bits = held
    return InputFrame.new(frame_number, direction_x, direction_y, held, pressed, released)

func _has_special() -> bool:
    return _own != null and _own.move_registry.has_move(MoveIds.SPECIAL_NEUTRAL)

func _charge_data() -> ChargeSpecialData:
    if not _has_special():
        return null
    var move := _own.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    return move.charge_special_data if move != null else null

func _charge_target_frames(distance: int) -> int:
    var data := _charge_data()
    if data == null:
        return 1
    var origin_frame := maxi(1, _simulation.frame_number - maxi(1, _own.state_machine.charge_frames) + 1)
    var variation := _roll(int(origin_frame / REACTION_INTERVAL_FRAMES), 7)
    if distance <= CLOSE_DISTANCE_UNITS:
        return 8 + (variation % 11) # Lv1: 8..18F
    if distance <= MID_DISTANCE_UNITS:
        if variation < 72:
            return 30 + (variation % 13) # Lv2: 30..42F
        return 10 + (variation % 9)
    if variation < 58:
        return 58 + (variation % 15) # Lv3: 58..72F
    if variation < 86:
        return 32 + (variation % 11)
    return 10 + (variation % 9)

func _can_use_ultimate() -> bool:
    if _own == null:
        return false
    var move := _own.move_registry.get_move(MoveIds.ULTIMATE)
    return move != null and _own.meter.can_spend(move.meter_cost)

func _roll(block: int, salt: int) -> int:
    # Deterministic integer mix; no wall-clock or RandomNumberGenerator state.
    var value := int(block) * 1103515245 + _own.fighter_id * 12345 + _seed + salt * 265443576
    value = value ^ (value >> 16)
    return absi(value) % 100
