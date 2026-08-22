class_name YaMouseRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/ya_mouse.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(c.mechanics.statuses[0].id, &"awkward_slow", "YA slow is a generic status")
    t.that(r.get_move(&"ya_wave_l2").on_start_effects[0].area != null, "YA Lv2 spawns persistent movement area")
    print("\nYA Mouse roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
