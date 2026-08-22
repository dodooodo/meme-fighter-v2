class_name AlienMeowRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/alien_meow.tres") as CharacterData
    var r := MoveRegistry.new(); t.that(r.configure(c.move_set), "Alien MoveSet validates")
    t.that(r.get_move(&"alien_scan_l3").on_hit_effects.size() > 0, "Alien Lv3 applies Signal Mark through authored effects")
    t.that(r.get_move(MoveIds.ULTIMATE).on_start_effects.size() == 2, "Alien Ultimate has normal/marked recorded-position sequence variants")
    print("\nAlien Meow roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
