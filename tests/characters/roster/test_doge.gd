class_name DogeRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/doge.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.that(r.get_move(&"doge_rush_l3").armor_data != null, "Doge Lv3 release owns one-hit strike armor data")
    t.equal(c.mechanics.modes[0].mode_id, &"super_doge", "Doge Ultimate mode is data-defined")
    print("\nDoge roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
