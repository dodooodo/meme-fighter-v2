# Future-affecting generic fighter mechanics state not owned by Meter/HFSM/Mode/Status.
class_name FighterMechanicsRuntime
extends RefCounted

var guard_exit_remaining: int = 0
var last_guard_posture: int = FighterStateMachine.GuardPosture.NONE
var movement_intent_x: int = 0
var air_attack_start_velocity: Vector2i = Vector2i.ZERO
var air_attack_start_facing: int = 1
var air_attack_jump_direction: int = 0
var forced_stand_remaining: int = 0
var armor_remaining_hits: int = 0
var armor_attack_instance_id: int = 0
var counter_attack_instance_id: int = 0
var wall_bounce_available: bool = true
var last_stand_active: bool = false
var last_stand_mode_serial: int = 0
var last_stand_resolve_gain_lock_remaining: int = 0
var panic_backstep_consumed_this_tick: bool = false
var panic_backstep_remaining_frames: int = 0
var _mechanics_data: CharacterMechanicsData

func configure(data: CharacterMechanicsData) -> void:
    _mechanics_data = data
    reset_for_round()

func reset_for_round() -> void:
    guard_exit_remaining = 0
    last_guard_posture = FighterStateMachine.GuardPosture.NONE
    movement_intent_x = 0
    air_attack_start_velocity = Vector2i.ZERO
    air_attack_start_facing = 1
    air_attack_jump_direction = 0
    forced_stand_remaining = 0
    armor_remaining_hits = 0
    armor_attack_instance_id = 0
    counter_attack_instance_id = 0
    wall_bounce_available = true
    last_stand_active = false
    last_stand_mode_serial = 0
    last_stand_resolve_gain_lock_remaining = 0
    panic_backstep_consumed_this_tick = false
    panic_backstep_remaining_frames = 0

func observe_control_context(state_machine: FighterStateMachine, parser: InputParser) -> void:
    panic_backstep_consumed_this_tick = false
    movement_intent_x = 1 if parser.forward_held else (-1 if parser.back_held else 0)
    if state_machine.state == FighterStateMachine.State.GUARD:
        last_guard_posture = state_machine.guard_posture
    elif last_guard_posture == FighterStateMachine.GuardPosture.CROUCHING and not parser.guard_held and movement_intent_x != 0:
        guard_exit_remaining = _mechanics_data.crouch_guard_exit_window_frames if _mechanics_data != null else 0
        last_guard_posture = FighterStateMachine.GuardPosture.NONE

func tick(frozen_by_hitstop: bool) -> void:
    if frozen_by_hitstop:
        return
    if guard_exit_remaining > 0:
        guard_exit_remaining -= 1
    if forced_stand_remaining > 0:
        forced_stand_remaining -= 1
    if panic_backstep_remaining_frames > 0:
        panic_backstep_remaining_frames -= 1
    if last_stand_resolve_gain_lock_remaining > 0:
        last_stand_resolve_gain_lock_remaining -= 1

func exiting_crouch_guard() -> bool:
    return guard_exit_remaining > 0 and movement_intent_x != 0

func record_air_attack_context(movement: MovementMotor) -> void:
    air_attack_start_velocity = movement.velocity_units
    air_attack_start_facing = movement.facing
    air_attack_jump_direction = 1 if movement.velocity_units.x * movement.facing > 0 else (-1 if movement.velocity_units.x * movement.facing < 0 else 0)

func backward_jump_attack() -> bool:
    return air_attack_jump_direction < 0

func late_descending_air_attack(movement: MovementMotor) -> bool:
    return movement != null and movement.velocity_units.y > 0

func begin_move_defenses(move: MoveData, attack_instance_id: int) -> void:
    armor_remaining_hits = 0
    armor_attack_instance_id = 0
    counter_attack_instance_id = 0
    if move == null:
        return
    if move.armor_data != null:
        armor_remaining_hits = move.armor_data.max_absorbed_hits
        armor_attack_instance_id = attack_instance_id
    if move.counter_data != null:
        counter_attack_instance_id = attack_instance_id

func armor_active(runner: MoveRunner, source_kind: int) -> bool:
    if runner == null or runner.current_move == null or runner.current_move.armor_data == null:
        return false
    var armor: ArmorData = runner.current_move.armor_data
    if armor_remaining_hits <= 0 or armor_attack_instance_id != runner.attack_instance_id:
        return false
    if runner.move_frame < armor.start_frame or runner.move_frame > armor.end_frame:
        return false
    var mask := ArmorData.SourceMask.STRIKE if source_kind == HitResult.AttackSourceKind.FIGHTER_BODY else ArmorData.SourceMask.PROJECTILE
    return (armor.valid_source_mask & mask) != 0

func consume_armor() -> void:
    armor_remaining_hits = maxi(0, armor_remaining_hits - 1)

func counter_active(runner: MoveRunner, source_kind: int) -> bool:
    if runner == null or runner.current_move == null or runner.current_move.counter_data == null:
        return false
    var counter: CounterData = runner.current_move.counter_data
    if counter_attack_instance_id != runner.attack_instance_id:
        return false
    if runner.move_frame < counter.start_frame or runner.move_frame > counter.end_frame:
        return false
    var mask := CounterData.SourceMask.STRIKE if source_kind == HitResult.AttackSourceKind.FIGHTER_BODY else CounterData.SourceMask.PROJECTILE
    return (counter.valid_source_mask & mask) != 0

func counter_success_move_id(runner: MoveRunner) -> StringName:
    if runner == null or runner.current_move == null or runner.current_move.counter_data == null:
        return &""
    return runner.current_move.counter_data.success_move_id

func last_stand_blocks_control() -> bool:
    return last_stand_active

func can_gain_last_stand_resolve() -> bool:
    return last_stand_active and last_stand_resolve_gain_lock_remaining <= 0

func record_last_stand_resolve_gain() -> void:
    last_stand_resolve_gain_lock_remaining = _mechanics_data.last_stand_resolve_gain_lock_frames if _mechanics_data != null else 0

func panic_status_id() -> StringName:
    return _mechanics_data.panic_exit_status_id if _mechanics_data != null else &""

func panic_backstep_speed_permille() -> int:
    return _mechanics_data.panic_backstep_speed_permille if _mechanics_data != null else 1000

func panic_backstep_startup_reduction() -> int:
    return _mechanics_data.panic_backstep_startup_reduction_frames if _mechanics_data != null else 0

func activate_panic_backstep(base_frames: int) -> void:
    panic_backstep_consumed_this_tick = true
    panic_backstep_remaining_frames = maxi(1, base_frames)

func panic_backstep_active() -> bool:
    return panic_backstep_remaining_frames > 0

func capture_state() -> Dictionary:
    return {
        "guard_exit_remaining": guard_exit_remaining,
        "last_guard_posture": last_guard_posture,
        "movement_intent_x": movement_intent_x,
        "air_attack_start_velocity": [air_attack_start_velocity.x, air_attack_start_velocity.y],
        "air_attack_start_facing": air_attack_start_facing,
        "air_attack_jump_direction": air_attack_jump_direction,
        "forced_stand_remaining": forced_stand_remaining,
        "armor_remaining_hits": armor_remaining_hits,
        "armor_attack_instance_id": armor_attack_instance_id,
        "counter_attack_instance_id": counter_attack_instance_id,
        "wall_bounce_available": wall_bounce_available,
        "last_stand_active": last_stand_active,
        "last_stand_mode_serial": last_stand_mode_serial,
        "last_stand_resolve_gain_lock_remaining": last_stand_resolve_gain_lock_remaining,
        "panic_backstep_remaining_frames": panic_backstep_remaining_frames,
    }

func restore_state(value: Dictionary) -> bool:
    guard_exit_remaining = maxi(0, int(value.get("guard_exit_remaining", 0)))
    last_guard_posture = int(value.get("last_guard_posture", FighterStateMachine.GuardPosture.NONE))
    movement_intent_x = clampi(int(value.get("movement_intent_x", 0)), -1, 1)
    var air: Array = value.get("air_attack_start_velocity", [0, 0])
    if air.size() != 2: return false
    air_attack_start_velocity = Vector2i(int(air[0]), int(air[1]))
    air_attack_start_facing = -1 if int(value.get("air_attack_start_facing", 1)) < 0 else 1
    air_attack_jump_direction = clampi(int(value.get("air_attack_jump_direction", 0)), -1, 1)
    forced_stand_remaining = maxi(0, int(value.get("forced_stand_remaining", 0)))
    armor_remaining_hits = maxi(0, int(value.get("armor_remaining_hits", 0)))
    armor_attack_instance_id = int(value.get("armor_attack_instance_id", 0))
    counter_attack_instance_id = int(value.get("counter_attack_instance_id", 0))
    wall_bounce_available = bool(value.get("wall_bounce_available", true))
    last_stand_active = bool(value.get("last_stand_active", false))
    last_stand_mode_serial = int(value.get("last_stand_mode_serial", 0))
    last_stand_resolve_gain_lock_remaining = maxi(0, int(value.get("last_stand_resolve_gain_lock_remaining", 0)))
    panic_backstep_remaining_frames = maxi(0, int(value.get("panic_backstep_remaining_frames", 0)))
    panic_backstep_consumed_this_tick = false
    return true
