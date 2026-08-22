class_name BladeShieldRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/blade_shield.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(r.get_move(MoveIds.STAND_HEAVY).hits.size(), 2, "Blade Shield Heavy is true two-hit MoveData")
    t.that(not c.mechanics.modes[0].guard_allowed, "Dual Blade mode disables Guard authoritatively")
    print("\nBlade Shield roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
