# Responsibility: M5 actual projectile HIT/BLOCK, shared CombatResolver guard, origin-side, meter, and detached confirm behavior.
class_name Milestone5ProjectileCombatTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var generic: CharacterData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_actual_zone_shot_hit()
    _test_actual_zone_shot_block()
    _test_guard_side_uses_projectile_origin_not_owner()
    _test_airborne_hit_and_protected_states()
    _test_old_projectile_does_not_pollute_current_move_connection()
    print("\nM5 Projectile Combat tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(ax: int = 50000, bx: int = 57000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(zone, generic, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _guard(frame: int, pressed: bool = false) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, 0, bit, bit if pressed else 0, 0)

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _tap_lv1_special(battle: BattleSimulation, defender_guarding: bool = false) -> void:
    var f := battle.frame_number + 1
    _tick(battle, InputFrame.with_special_press(f), _guard(f, true) if defender_guarding else null)
    f = battle.frame_number + 1
    _tick(battle, null, _guard(f) if defender_guarding else null)

func _test_actual_zone_shot_hit() -> void:
    var battle := _battle()
    _tap_lv1_special(battle)
    for _i in range(14):
        _tick(battle)
    t.equal(battle.frame_number, 16, "Zone projectile still spawns on MoveRunner F15 after one charge-entry tick")
    t.equal(battle.fighter_b.combatant.hp, 5000, "Spawn frame body move deals no damage")
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, 4920, "Zone projectile HIT applies ProjectileData damage 80")
    t.equal(battle.fighter_b.combatant.hitstun_remaining, 16, "Projectile HIT applies 16F hitstun before status tick accounting")
    t.equal(battle.fighter_b.combatant.hitstop_remaining, 3, "Projectile HIT enters 4F hitstop then status tick consumes current frame")
    t.equal(battle.fighter_b.combatant.knockback_velocity_x_units, 700, "Projectile HIT applies directional knockback")
    t.equal(battle.fighter_a.meter.get_value(), 70, "Projectile HIT awards owner +14 meter")
    t.equal(battle.projectile_system.active_count(), 0, "Single-hit projectile despawns after HIT")

func _test_actual_zone_shot_block() -> void:
    var battle := _battle()
    _tap_lv1_special(battle, true)
    for _i in range(14):
        var f := battle.frame_number + 1
        _tick(battle, null, _guard(f))
    var hit_frame := battle.frame_number + 1
    _tick(battle, null, _guard(hit_frame))
    t.equal(battle.fighter_b.combatant.hp, 5000, "Projectile BLOCK deals zero prototype chip")
    t.equal(battle.fighter_b.combatant.blockstun_remaining, 12, "Projectile BLOCK applies 12F blockstun before status tick accounting")
    t.equal(battle.fighter_a.meter.get_value(), 30, "Projectile BLOCK awards owner +6 meter")
    t.equal(battle.fighter_b.combatant.last_result_type, HitResult.ResultType.BLOCK, "Projectile uses canonical HitResult.BLOCK")
    t.equal(battle.projectile_system.active_count(), 0, "Projectile despawns after BLOCK")

func _spawn_direct(battle: BattleSimulation) -> ProjectileRuntime:
    var move := battle.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    return battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, move.projectile_spawns[0])

func _test_guard_side_uses_projectile_origin_not_owner() -> void:
    var battle := _battle(30000, 60000)
    var projectile := _spawn_direct(battle)
    battle.fighter_b.state_machine.transition_to(FighterStateMachine.State.GUARD)
    battle.fighter_b.state_machine.guard_posture = FighterStateMachine.GuardPosture.STANDING
    battle.fighter_b.movement_motor.facing = -1
    # Owner crosses behind defender, projectile remains on defender's front/left side.
    battle.fighter_a.movement_motor.sim_position.x = 90000
    projectile.position_units = Vector2i(59000, BattleSimulation.GROUND_Y_UNITS - 7000)
    var contacts := battle.projectile_system.build_contacts(battle.fighter_a, battle.fighter_b)
    t.equal(contacts.size(), 1, "Front projectile contact builds after owner crosses behind")
    var front_result := battle.combat_resolver.resolve_projectile_contact(contacts[0], projectile.projectile_data, battle.fighter_a, battle.fighter_b)
    t.equal(front_result.result_type, HitResult.ResultType.BLOCK, "Front projectile BLOCK uses projectile origin, not owner position")

    projectile.position_units = Vector2i(61000, BattleSimulation.GROUND_Y_UNITS - 7000)
    contacts = battle.projectile_system.build_contacts(battle.fighter_a, battle.fighter_b)
    t.equal(contacts.size(), 1, "Behind projectile contact builds")
    var back_result := battle.combat_resolver.resolve_projectile_contact(contacts[0], projectile.projectile_data, battle.fighter_a, battle.fighter_b)
    t.equal(back_result.result_type, HitResult.ResultType.HIT, "Projectile arriving from defender back cannot be blocked")

func _test_airborne_hit_and_protected_states() -> void:
    var battle := _battle(30000, 60000)
    var projectile := _spawn_direct(battle)
    projectile.position_units = Vector2i(59000, BattleSimulation.GROUND_Y_UNITS - 7000)
    battle.fighter_b.state_machine.transition_to(FighterStateMachine.State.JUMP)
    var contacts := battle.projectile_system.build_contacts(battle.fighter_a, battle.fighter_b)
    t.equal(contacts.size(), 1, "Projectile geometry can contact airborne defender")
    var result := battle.combat_resolver.resolve_projectile_contact(contacts[0], projectile.projectile_data, battle.fighter_a, battle.fighter_b)
    t.equal(result.result_type, HitResult.ResultType.HIT, "Airborne defender has no air guard and projectile resolves HIT")
    battle.fighter_b.state_machine.state = FighterStateMachine.State.GETUP
    battle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.HIT_REACTION
    t.equal(battle.projectile_system.build_contacts(battle.fighter_a, battle.fighter_b).size(), 0, "Projectile respects existing GETUP strike protection")
    battle.fighter_b.state_machine.state = FighterStateMachine.State.KO
    battle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.DEAD
    battle.fighter_b.combatant.is_ko = true
    t.equal(battle.projectile_system.build_contacts(battle.fighter_a, battle.fighter_b).size(), 0, "Projectile never targets KO defender")

func _test_old_projectile_does_not_pollute_current_move_connection() -> void:
    var battle := _battle(30000, 90000)
    var projectile := _spawn_direct(battle)
    projectile.position_units = Vector2i(89000, BattleSimulation.GROUND_Y_UNITS - 7000)
    var light := battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT)
    battle.fighter_a.move_runner.start_move(light)
    battle.fighter_a.hitbox_owner.begin_attack_instance(battle.fighter_a.move_runner.attack_instance_id)
    battle.fighter_a.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    t.that(not battle.fighter_a.move_runner.connected_hit, "New current Light begins with no hit connection")
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, 4920, "Detached old projectile can hit while owner performs another move")
    t.that(not battle.fighter_a.move_runner.connected_hit, "Detached projectile HIT does not write current MoveRunner connected_hit")
