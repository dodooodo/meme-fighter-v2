# M7 ProjectileRuntime -> presentation instance-map tests.
class_name ProjectilePresentationTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var generic: CharacterData
var zone_presentation: CharacterPresentationData
var generic_presentation: CharacterPresentationData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    zone_presentation = load("res://presentation/characters/zone_fighter_presentation.tres") as CharacterPresentationData
    generic_presentation = load("res://presentation/characters/generic_fighter_presentation.tres") as CharacterPresentationData
    _test_spawn_move_facing_and_cleanup()
    print("\nM7 ProjectilePresentation tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_spawn_move_facing_and_cleanup() -> void:
    var battle := BattleSimulation.new()
    battle.configure(zone, generic)
    var special := battle.fighter_a.move_registry.get_move(&"special_neutral")
    var descriptor: ProjectileSpawnData = special.projectile_spawns[0]
    var first := battle.projectile_system.spawn_from_descriptor(battle.fighter_a, special.id, 0, descriptor)
    var presenter := ProjectileVisualPresenter.new()
    var presentations: Array[CharacterPresentationData] = [zone_presentation, generic_presentation]
    presenter.configure(battle, presentations)
    t.equal(presenter.visual_count(), 1, "zone_shot ProjectileInstanceID creates one presentation visual")
    t.that(presenter.has_visual(first.instance_id), "Projectile visual map keys by deterministic ProjectileInstanceID")
    var first_visual := presenter.visual_for(first.instance_id)
    t.equal(first_visual.position, SimulationRenderConverter.to_pixels(first.position_units), "Projectile visual follows authoritative runtime position")
    var captured_facing := first.facing
    battle.fighter_a.movement_motor.facing = -captured_facing
    presenter.sync_from_simulation()
    var greybox := first_visual as GreyboxProjectileVisual
    t.equal(greybox.facing, captured_facing, "Owner facing change does not flip detached projectile visual")
    var second := battle.projectile_system.spawn_from_descriptor(battle.fighter_a, special.id, 0, descriptor)
    presenter.sync_from_simulation()
    t.equal(presenter.visual_count(), 2, "Two concurrent projectiles create two independent visual instances")
    t.that(first.instance_id != second.instance_id, "Concurrent presentation map follows unique runtime IDs")
    battle.projectile_system.clear_active()
    presenter.sync_from_simulation()
    t.equal(presenter.visual_count(), 0, "Gameplay projectile despawn/cleanup removes stale visual IDs")
    presenter.free()
