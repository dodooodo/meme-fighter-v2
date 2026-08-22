class_name MagicOrangeCatRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/magic_orange_cat.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(r.get_move(&"magic_circle_l2").on_start_effects[0].area.replace_group, &"jpeg_circle", "JPEG circles share replace group")
    t.equal(r.get_move(MoveIds.ULTIMATE).on_start_effects[0].sequence.steps.size(), 5, "Cthulhu Ultimate has four tentacles plus pulse")
    print("\nMagic Orange Cat roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
