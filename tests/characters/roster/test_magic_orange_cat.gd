class_name MagicOrangeCatRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := RosterRegistry.character_by_id(&"magic_orange_cat")
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(r.get_move(&"magic_circle_l2").on_start_effects[0].area.replace_group, &"jpeg_circle", "JPEG circles share replace group")
    var zones := r.get_move(MoveIds.ULTIMATE).on_start_effects[0].sequence.steps
    t.equal(zones.size(), 4, "Cthulhu Ultimate has exactly four warned attack zones")
    for zone: SequenceStepData in zones:
        t.equal(zone.telegraph_frames, 24, "Cthulhu Ultimate zone warning is 24F")
    print("\nMagic Orange Cat roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
