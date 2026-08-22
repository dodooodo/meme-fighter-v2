# Responsibility: M5 BattleSimulation projectile spawn timing, integer movement, facing, hitstop freeze, and concurrency.
class_name Milestone5ProjectileSpawnTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var generic: CharacterData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_special_spawn_exactly_once_and_next_frame_movement()
    _test_spawn_mirrors_with_facing_and_is_detached()
    _test_hitstop_freezes_projectile_motion_and_lifetime()
    _test_multiple_concurrent_projectiles()
    print("\nM5 Projectile Spawn tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(ax: int = 50000, bx: int = 100000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(zone, generic, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _advance(battle: BattleSimulation, count: int) -> void:
    for _i in range(count):
        _tick(battle)

func _tap_lv1_special(battle: BattleSimulation) -> void:
    var press_frame := battle.frame_number + 1
    _tick(battle, InputFrame.with_special_press(press_frame))
    _tick(battle) # released/neutral input starts Lv1 through the M8 charge runtime

func _test_special_spawn_exactly_once_and_next_frame_movement() -> void:
    var battle := _battle()
    _tap_lv1_special(battle)
    _advance(battle, 13)
    t.equal(battle.frame_number, 15, "Zone Lv1 MoveRunner reaches move F14 after one M8 charge-entry tick")
    t.equal(battle.projectile_system.active_count(), 0, "No projectile before Special move F15")
    _tick(battle)
    t.equal(battle.frame_number, 16, "Tap-charge shifts only input entry; projectile still spawns on authoritative move F15")
    t.equal(battle.projectile_system.active_count(), 1, "Special move F15 spawns exactly one projectile")
    var projectile := battle.projectile_system.active_projectiles()[0]
    t.equal(projectile.instance_id, 1, "First projectile gets deterministic instance ID 1")
    t.equal(projectile.position_units, Vector2i(50100, BattleSimulation.GROUND_Y_UNITS - 70), "Projectile starts at integer spawn position")
    t.equal(projectile.remaining_lifetime_frames, 120, "New projectile receives no lifetime decrement on spawn frame")
    t.equal(battle.fighter_a.move_runner.spawned_projectile_indices(), [0], "MoveRunner records descriptor as spawned")
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 1, "Projectile remains active one frame later")
    projectile = battle.projectile_system.active_projectiles()[0]
    t.equal(projectile.position_units.x, 50900, "Normal projectile advances exactly 800 integer units on next frame")
    t.equal(projectile.remaining_lifetime_frames, 119, "Lifetime decrements on first movement frame")
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 1, "Same move frame history never duplicates projectile")
    t.equal(battle.projectile_system.next_projectile_instance_serial, 2, "No duplicate spawn consumes serial")

func _test_spawn_mirrors_with_facing_and_is_detached() -> void:
    var battle := _battle(100000, 50000)
    t.equal(battle.fighter_a.movement_motor.facing, -1, "Zone starts facing left when opponent is left")
    _tap_lv1_special(battle)
    _advance(battle, 14)
    var projectile := battle.projectile_system.active_projectiles()[0]
    t.equal(projectile.facing, -1, "Projectile captures simulation facing at spawn")
    t.equal(projectile.position_units.x, 99900, "Spawn offset mirrors by facing")
    battle.fighter_a.movement_motor.facing = 1
    battle.fighter_a.movement_motor.sim_position.x = 30000
    _tick(battle)
    projectile = battle.projectile_system.active_projectiles()[0]
    t.equal(projectile.facing, -1, "Owner facing changes do not alter detached projectile facing")
    t.equal(projectile.position_units.x, 99100, "Detached projectile keeps its own trajectory")

func _test_hitstop_freezes_projectile_motion_and_lifetime() -> void:
    var battle := _battle()
    _tap_lv1_special(battle)
    _advance(battle, 14)
    var before := battle.projectile_system.active_projectiles()[0]
    var before_pos := before.position_units
    var before_life := before.remaining_lifetime_frames
    battle.fighter_a.combatant.hitstop_remaining = 2
    _tick(battle)
    var frozen := battle.projectile_system.active_projectiles()[0]
    t.equal(frozen.position_units, before_pos, "Battle hitstop freezes projectile position")
    t.equal(frozen.remaining_lifetime_frames, before_life, "Battle hitstop freezes projectile lifetime")
    t.equal(battle.projectile_system.active_count(), 1, "Hitstop cannot duplicate projectile spawn")

func _test_multiple_concurrent_projectiles() -> void:
    var battle := _battle()
    _tap_lv1_special(battle)
    _advance(battle, 34)
    t.equal(battle.frame_number, 36, "First Lv1 Special completes its unchanged 35F MoveData timeline after the charge-entry tick")
    _tap_lv1_special(battle)
    _advance(battle, 14)
    t.equal(battle.projectile_system.active_count(), 2, "Same owner may have two concurrent projectiles")
    var active := battle.projectile_system.active_projectiles()
    t.that(active[0].instance_id != active[1].instance_id, "Concurrent projectiles have unique deterministic IDs")
    t.that(active[0].position_units != active[1].position_units, "Concurrent projectiles maintain independent positions")
    t.that(active[0].remaining_lifetime_frames != active[1].remaining_lifetime_frames, "Concurrent projectiles maintain independent lifetimes")
