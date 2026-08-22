# Responsibility: M5 projectile lifetime, owner-state independence, KO cleanup, and deterministic reset lifecycle.
class_name Milestone5ProjectileLifecycleTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var generic: CharacterData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_lifetime_exact_and_no_screen_dependency()
    _test_owner_hitstun_does_not_destroy_projectile()
    _test_owner_ko_cleanup_after_tick()
    _test_reset_clears_projectiles_and_serial()
    _test_super_meter_spawn_and_no_refund()
    _test_actual_super_projectile_hit()
    print("\nM5 Projectile Lifecycle tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(ax: int = 30000, bx: int = 110000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(zone, generic, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _spawn(battle: BattleSimulation, move_id: StringName = MoveIds.SPECIAL_NEUTRAL) -> ProjectileRuntime:
    var move := battle.fighter_a.move_registry.get_move(move_id)
    return battle.projectile_system.spawn_from_descriptor(battle.fighter_a, move_id, 0, move.projectile_spawns[0])

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _test_lifetime_exact_and_no_screen_dependency() -> void:
    var battle := _battle()
    var projectile := _spawn(battle)
    projectile.position_units = Vector2i(-500000, 0)
    for _i in range(119):
        _tick(battle)
    t.equal(battle.projectile_system.active_count(), 1, "Projectile remains active after 119 movement/lifetime steps even far off-screen")
    t.equal(battle.projectile_system.active_projectiles()[0].remaining_lifetime_frames, 1, "Lifetime convention reaches 1 after 119 steps")
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 0, "Projectile expires exactly when remaining lifetime reaches zero")

func _test_owner_hitstun_does_not_destroy_projectile() -> void:
    var battle := _battle()
    var projectile := _spawn(battle)
    projectile.position_units = Vector2i(50000, 10000)
    battle.fighter_a.combatant.hitstun_remaining = 5
    battle.fighter_a.state_machine.transition_to(FighterStateMachine.State.HITSTUN)
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 1, "Projectile survives owner HITSTUN")
    t.equal(battle.projectile_system.active_projectiles()[0].instance_id, projectile.instance_id, "Owner HITSTUN preserves projectile identity")

func _test_owner_ko_cleanup_after_tick() -> void:
    var battle := _battle()
    _spawn(battle)
    _spawn(battle)
    t.equal(battle.projectile_system.active_count(), 2, "KO cleanup setup has two owner projectiles")
    battle.fighter_a.combatant.hp = 0
    battle.fighter_a.combatant.is_ko = true
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 0, "Owner KO clears remaining projectiles at end of tick")

func _test_reset_clears_projectiles_and_serial() -> void:
    var battle := _battle()
    _spawn(battle)
    _spawn(battle)
    t.equal(battle.projectile_system.next_projectile_instance_serial, 3, "Serial advances before reset")
    battle.reset_projectiles()
    t.equal(battle.projectile_system.active_count(), 0, "Battle reset hook clears all projectiles")
    t.equal(battle.projectile_system.next_projectile_instance_serial, ProjectileSystem.INITIAL_INSTANCE_SERIAL, "Battle reset restores projectile serial to deterministic initial value")

func _test_super_meter_spawn_and_no_refund() -> void:
    var battle := _battle()
    battle.fighter_a.meter.set_value(100)
    _tick(battle, InputFrame.with_ultimate_press(1))
    t.equal(battle.fighter_a.meter.get_value(), 0, "Ultimate spends 100 meter immediately")
    for _i in range(17):
        _tick(battle)
    t.equal(battle.projectile_system.active_count(), 0, "No super projectile before F19")
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 1, "Ultimate F19 spawns one super projectile")
    var projectile := battle.projectile_system.active_projectiles()[0]
    t.equal(projectile.projectile_id, &"zone_super_shot", "Ultimate spawns zone_super_shot")
    t.equal(projectile.projectile_data.damage, 220, "Super projectile carries 220 damage payload")
    battle.projectile_system.clear_all()
    t.equal(battle.fighter_a.meter.get_value(), 0, "Ultimate projectile whiff/despawn never refunds cost")

func _test_actual_super_projectile_hit() -> void:
    var battle := BattleSimulation.new()
    battle.configure(zone, generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS))
    battle.fighter_a.meter.set_value(100)
    _tick(battle, InputFrame.with_ultimate_press(1))
    for _i in range(17):
        _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, 5000, "Super body move deals no damage before F19 spawn")
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, 4780, "zone_super_shot applies 220 ProjectileData damage")
    t.equal(battle.fighter_b.combatant.hitstun_remaining, 26, "Super projectile applies 26F hitstun")
    t.equal(battle.fighter_b.combatant.hitstop_remaining, 7, "Super projectile 8F defender hitstop begins on impact frame")
    t.equal(battle.fighter_b.combatant.knockback_velocity_x_units, 1500, "Super projectile applies 1500 horizontal knockback")
    t.equal(battle.fighter_b.combatant.knockback_velocity_y_units, -400, "Super projectile applies -400 vertical knockback")
    t.equal(battle.fighter_a.meter.get_value(), 0, "Super projectile impact grants no meter after cost")
    t.equal(battle.projectile_system.active_count(), 0, "Super projectile despawns on HIT")
