# Responsibility: Integer-unit horizontal/vertical fighter movement, gravity, ground contact, and stage-X clamping.
# Owns: simulation position/velocity, facing, ground/stage bounds, landing fact for the current tick.
# Does NOT own: input devices, HP, collision outcomes, presentation transforms, state transition policy.
# Dependencies: CharacterData, Combatant, FighterStateMachine, InputParser, SimulationUnits.
class_name MovementMotor
extends RefCounted

var sim_position: Vector2i = Vector2i.ZERO
var velocity_units: Vector2i = Vector2i.ZERO
var facing: int = 1
var stage_left_units: int = 8000
var stage_right_units: int = 120000
var ground_y_units: int = 56000
var landed_this_frame: bool = false

func configure(start_position: Vector2i, p_stage_left: int, p_stage_right: int, p_ground_y: int) -> void:
    sim_position = start_position
    stage_left_units = p_stage_left
    stage_right_units = p_stage_right
    ground_y_units = p_ground_y
    sim_position.y = ground_y_units
    velocity_units = Vector2i.ZERO
    landed_this_frame = false

func update_facing(opponent_x_units: int) -> void:
    if opponent_x_units > sim_position.x:
        facing = 1
    elif opponent_x_units < sim_position.x:
        facing = -1

func begin_jump(data: CharacterData) -> void:
    if data == null or is_airborne():
        return
    velocity_units.y = data.jump_velocity_y_units_per_tick

func tick(state_machine: FighterStateMachine, combatant: Combatant, data: CharacterData, parser: InputParser, runner: MoveRunner = null, statuses: StatusEffectComponent = null, mode: ModeComponent = null, mechanics_runtime: FighterMechanicsRuntime = null, resources: FighterResourceComponent = null) -> void:
    landed_this_frame = false

    # Hitstop freezes integration only. Velocity is intentionally preserved for airborne rollback-friendly semantics.
    if combatant.hitstop_remaining > 0:
        return

    if combatant.is_ko:
        _tick_ko(combatant, data)
        clamp_x_to_stage()
        return

    if combatant.hitstun_remaining > 0:
        _tick_hitstun(combatant, data)
        clamp_x_to_stage()
        return

    if combatant.blockstun_remaining > 0:
        velocity_units.x = 0
        if not is_airborne():
            velocity_units.y = 0
            sim_position.y = ground_y_units
        clamp_x_to_stage()
        return

    match state_machine.state:
        FighterStateMachine.State.JUMP, FighterStateMachine.State.AIR_ATTACK:
            _apply_air_horizontal(parser, data, statuses, mode)
            _integrate_air_vertical(data)
        FighterStateMachine.State.DASH_FORWARD:
            velocity_units.y = 0
            sim_position.y = ground_y_units
            var dash_permille := (statuses.movement_permille(&"dash") if statuses != null else 1000) * (mode.movement_permille(&"dash") if mode != null else 1000) / 1000
            velocity_units.x = facing * data.dash_speed_units_per_tick * dash_permille / 1000 if state_machine.dash_move_remaining > 0 else 0
            sim_position.x += velocity_units.x
        FighterStateMachine.State.BACKSTEP:
            velocity_units.y = 0
            sim_position.y = ground_y_units
            var back_permille := (statuses.movement_permille(&"backstep") if statuses != null else 1000) * (mode.movement_permille(&"backstep") if mode != null else 1000) / 1000
            if mechanics_runtime != null and mechanics_runtime.panic_backstep_active(): back_permille = back_permille * mechanics_runtime.panic_backstep_speed_permille() / 1000
            velocity_units.x = -facing * data.backstep_speed_units_per_tick * back_permille / 1000 if state_machine.dash_move_remaining > 0 else 0
            sim_position.x += velocity_units.x
        FighterStateMachine.State.GROUND_ATTACK:
            var travel := runner.current_move.travel_x_for_frame(runner.move_frame) if runner != null and runner.current_move != null else 0
            _ground_horizontal(facing * travel)
        FighterStateMachine.State.CHARGE:
            _ground_horizontal(0)
        FighterStateMachine.State.WALK_FORWARD:
            var forward_permille := _movement_permille(statuses, mode, &"walk", &"walk_forward")
            if resources != null: forward_permille = forward_permille * resources.movement_permille(&"walk_forward") / 1000
            _ground_horizontal(facing * data.walk_forward_units_per_tick * forward_permille / 1000)
        FighterStateMachine.State.WALK_BACK:
            _ground_horizontal(-facing * data.walk_back_units_per_tick * _movement_permille(statuses, mode, &"walk", &"walk_back") / 1000)
        _:
            _ground_horizontal(0)

    clamp_x_to_stage()

func _ground_horizontal(speed_x: int) -> void:
    velocity_units.x = speed_x
    velocity_units.y = 0
    sim_position.x += velocity_units.x
    sim_position.y = ground_y_units

func _apply_air_horizontal(parser: InputParser, data: CharacterData, statuses: StatusEffectComponent = null, mode: ModeComponent = null) -> void:
    if parser.forward_held:
        velocity_units.x = facing * data.air_forward_units_per_tick * (mode.movement_permille(&"air_forward") if mode != null else 1000) / 1000
    elif parser.back_held:
        velocity_units.x = -facing * data.air_back_units_per_tick * (mode.movement_permille(&"air_back") if mode != null else 1000) / 1000
    else:
        velocity_units.x = 0
    sim_position.x += velocity_units.x

func _integrate_air_vertical(data: CharacterData) -> void:
    sim_position.y += velocity_units.y
    velocity_units.y = mini(velocity_units.y + data.gravity_y_units_per_tick2, data.max_fall_speed_y_units_per_tick)
    resolve_ground_contact()

func _tick_hitstun(combatant: Combatant, data: CharacterData) -> void:
    velocity_units.x = combatant.knockback_velocity_x_units
    sim_position.x += velocity_units.x
    combatant.knockback_velocity_x_units = int(round(float(combatant.knockback_velocity_x_units) * 0.75))

    if is_airborne() or combatant.knockback_velocity_y_units < 0:
        velocity_units.y = combatant.knockback_velocity_y_units
        sim_position.y += velocity_units.y
        combatant.knockback_velocity_y_units = mini(
            combatant.knockback_velocity_y_units + data.gravity_y_units_per_tick2,
            data.max_fall_speed_y_units_per_tick
        )
        velocity_units.y = combatant.knockback_velocity_y_units
        resolve_ground_contact()
        if not is_airborne():
            combatant.knockback_velocity_y_units = 0
    else:
        velocity_units.y = 0
        sim_position.y = ground_y_units

func _tick_ko(combatant: Combatant, data: CharacterData) -> void:
    velocity_units.x = 0
    if not is_airborne() and combatant.knockback_velocity_y_units < 0:
        velocity_units.y = combatant.knockback_velocity_y_units
    if is_airborne() or velocity_units.y < 0:
        sim_position.y += velocity_units.y
        velocity_units.y = mini(velocity_units.y + data.gravity_y_units_per_tick2, data.max_fall_speed_y_units_per_tick)
        resolve_ground_contact()
    else:
        velocity_units.y = 0
        sim_position.y = ground_y_units

func resolve_ground_contact() -> void:
    if sim_position.y >= ground_y_units:
        if sim_position.y > ground_y_units or velocity_units.y > 0:
            landed_this_frame = true
        sim_position.y = ground_y_units
        velocity_units.y = 0

func clamp_x_to_stage() -> void:
    sim_position.x = clampi(sim_position.x, stage_left_units, stage_right_units)

func clamp_to_stage() -> void:
    # Compatibility alias: M2 Complete deliberately clamps X only; ground contact is a separate operation.
    clamp_x_to_stage()

func translate_x_units(amount: int) -> void:
    sim_position.x += amount
    clamp_x_to_stage()

func is_airborne() -> bool:
    return sim_position.y < ground_y_units

func position_pixels() -> Vector2:
    return SimulationUnits.vector_units_to_pixels(sim_position)

func _movement_permille(statuses: StatusEffectComponent, mode: ModeComponent, status_kind: StringName, mode_kind: StringName) -> int:
    var value := statuses.movement_permille(status_kind) if statuses != null else 1000
    value = value * (mode.movement_permille(mode_kind) if mode != null else 1000) / 1000
    return value
