class_name YaMouseRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/ya_mouse.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(c.mechanics.statuses[0].id, &"awkward_slow", "YA slow is a generic status")
    t.that(r.get_move(&"ya_wave_l2").on_start_effects[0].area != null, "YA Lv2 spawns persistent movement area")
    var l3_slow := r.get_move(&"ya_wave_l3").on_start_effects[0].area.while_inside_status
    t.equal(l3_slow.walk_speed_permille, 780, "YA Lv3 Slow keeps walk at the 0.78 floor")
    t.equal(l3_slow.dash_speed_permille, 740, "YA Lv3 Slow keeps dash at the 0.74 floor")
    t.equal(l3_slow.backstep_speed_permille, 740, "YA Lv3 Slow keeps backstep at the 0.74 floor")
    print("\nYA Mouse roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
