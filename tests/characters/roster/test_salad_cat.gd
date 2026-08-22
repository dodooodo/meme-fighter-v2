class_name SaladCatRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/salad_cat.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.that(r.get_move(MoveIds.CROUCH_LOW).on_hit_effects[0].positioning != null, "Salad Low uses SET_TARGET_SEPARATION positioning")
    t.that(r.get_move(MoveIds.ULTIMATE).on_start_effects[0].sequence.steps.size() == 3, "Salad Ultimate is authored High/Low sequence")
    print("\nSalad Cat roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
