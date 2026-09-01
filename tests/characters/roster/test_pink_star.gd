class_name PinkStarRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/pink_star.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(c.mechanics.resources[0].max_value, 5, "Pink True Face resource max is five")
    t.equal(r.get_move(&"pink_true_heavy").resource_cost_amount, 1, "True Heavy spends one face action")
    t.that(c.mechanics.modes[0].finisher_enabled, "Pink True Face finisher is enabled")
    t.equal(c.mechanics.modes[0].finisher_min_resource, 2, "Pink Finisher requires at least two Stars")
    t.equal(c.mechanics.modes[0].finisher_tiers.size(), 4, "Pink Finisher owns four resource tiers")
    print("\nPink Star roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
