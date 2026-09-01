# Generic deterministic integer positioning effects with stage clamping.
class_name PositioningSystem
extends RefCounted

func apply(effect: PositioningEffectData, attacker: Fighter, defender: Fighter, stage_left: int, stage_right: int) -> void:
    if effect == null or attacker == null or defender == null:
        return
    match effect.type:
        PositioningEffectData.Type.PUSH_DEFENDER:
            defender.movement_motor.translate_x_units(attacker.movement_motor.facing * effect.distance_units)
        PositioningEffectData.Type.PUSH_ATTACKER:
            attacker.movement_motor.translate_x_units(-attacker.movement_motor.facing * effect.distance_units)
        PositioningEffectData.Type.SET_TARGET_SEPARATION, PositioningEffectData.Type.KEEP_CLOSE, PositioningEffectData.Type.RESET_TO_MID_RANGE:
            _set_separation(attacker, defender, absi(effect.distance_units), stage_left, stage_right)
        PositioningEffectData.Type.PUSH_TO_MINIMUM_SEPARATION:
            _push_to_minimum_separation(attacker, defender, absi(effect.distance_units), stage_left, stage_right)
        PositioningEffectData.Type.SIDE_SWITCH:
            _side_switch(attacker, defender, stage_left, stage_right)
        PositioningEffectData.Type.PUSH_BOTH_APART, PositioningEffectData.Type.CORNER_SAFE_RESET:
            var amount := absi(effect.distance_units)
            attacker.movement_motor.translate_x_units(-attacker.movement_motor.facing * (amount / 2))
            defender.movement_motor.translate_x_units(attacker.movement_motor.facing * (amount - amount / 2))
    attacker.movement_motor.clamp_x_to_stage()
    defender.movement_motor.clamp_x_to_stage()

func apply_block_pushback(result: HitResult, attacker: Fighter, defender: Fighter, stage_left: int, stage_right: int) -> void:
    if result == null or attacker == null or defender == null:
        return
    var defender_push := result.defender_block_pushback_units
    var source_move := attacker.move_registry.get_move(result.move_id)
    defender_push = (defender_push * defender.defense_modifiers.block_pushback_permille(source_move)) / 1000
    defender.movement_motor.translate_x_units(attacker.movement_motor.facing * defender_push)
    attacker.movement_motor.translate_x_units(-attacker.movement_motor.facing * result.attacker_block_recoil_units)
    attacker.movement_motor.clamp_x_to_stage()
    defender.movement_motor.clamp_x_to_stage()

func _set_separation(attacker: Fighter, defender: Fighter, distance_units: int, stage_left: int, stage_right: int) -> void:
    var sign := attacker.movement_motor.facing
    var desired_defender_x := attacker.movement_motor.sim_position.x + sign * distance_units
    defender.movement_motor.sim_position.x = clampi(desired_defender_x, stage_left, stage_right)
    var actual := absi(defender.movement_motor.sim_position.x - attacker.movement_motor.sim_position.x)
    if actual < distance_units:
        attacker.movement_motor.sim_position.x = clampi(defender.movement_motor.sim_position.x - sign * distance_units, stage_left, stage_right)

func _push_to_minimum_separation(attacker: Fighter, defender: Fighter, distance_units: int, stage_left: int, stage_right: int) -> void:
    var attacker_x := attacker.movement_motor.sim_position.x
    var defender_x := defender.movement_motor.sim_position.x
    var current_distance := absi(defender_x - attacker_x)
    if current_distance >= distance_units:
        return
    # Geometry, rather than world direction or a character ID, defines "outward".
    var sign := 1 if defender_x >= attacker_x else -1
    defender.movement_motor.sim_position.x = clampi(attacker_x + sign * distance_units, stage_left, stage_right)
    var achieved_distance := absi(defender.movement_motor.sim_position.x - attacker_x)
    if achieved_distance < distance_units:
        attacker.movement_motor.sim_position.x = clampi(defender.movement_motor.sim_position.x - sign * distance_units, stage_left, stage_right)

func _side_switch(attacker: Fighter, defender: Fighter, stage_left: int, stage_right: int) -> void:
    var ax := attacker.movement_motor.sim_position.x
    var dx := defender.movement_motor.sim_position.x
    attacker.movement_motor.sim_position.x = clampi(dx, stage_left, stage_right)
    defender.movement_motor.sim_position.x = clampi(ax, stage_left, stage_right)
