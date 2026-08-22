class_name SauceStubbleDogRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/sauce_stubble_dog.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(c.mechanics.statuses[0].id, &"sauce", "Sauce debuff is a timed status")
    t.equal(r.get_move(&"sauce_shot_l1").projectile_spawns.size(), 1, "Sauce Special uses real ProjectileData")
    t.equal(r.get_move(MoveIds.ULTIMATE).on_start_effects[0].sequence.steps.size(), 6, "Sauce Ultimate authors four passes plus two mutually-exclusive finals")
    print("\nSauce Stubble Dog roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
