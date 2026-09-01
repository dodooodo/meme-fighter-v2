class_name DogeRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := RosterRegistry.character_by_id(&"doge")
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.that(r.get_move(&"doge_rush_l1").armor_data == null, "Doge Lv1 Rush has no armor")
    t.that(r.get_move(&"doge_rush_l2").armor_data == null, "Doge Lv2 Rush has no armor")
    t.that(r.get_move(&"doge_rush_l3").armor_data != null, "Doge Lv3 release owns one-hit strike armor data")
    t.equal(r.get_move(&"doge_rush_l3").armor_data.valid_source_mask, ArmorData.SourceMask.STRIKE, "Doge Lv3 armor is strike-only")
    t.equal(c.mechanics.modes[0].mode_id, &"super_doge", "Doge Ultimate mode is data-defined")
    print("\nDoge roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
