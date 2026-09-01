class_name OkMeowBossRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/ok_meow_boss.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(r.get_move(MoveIds.ULTIMATE).throw_kind, MoveData.ThrowKind.GROUND_CAPTURE_SUPER, "OK Ultimate is Ground Capture Super, not cinematic auto-hit")
    t.equal(r.get_move(MoveIds.ULTIMATE).throw_conditions.size(), 3, "Ground Capture validates grounded/grabbable/not ordinary hitstun")
    t.equal(r.get_move(&"ok_pressure_l1").blockstun_frames - r.get_move(&"ok_pressure_l1").recovery_frames, -2, "OK Lv1 block advantage is -2")
    t.equal(r.get_move(&"ok_pressure_l2").blockstun_frames - r.get_move(&"ok_pressure_l2").recovery_frames, 1, "OK Lv2 block advantage is +1")
    t.equal(r.get_move(&"ok_pressure_l3").blockstun_frames - r.get_move(&"ok_pressure_l3").recovery_frames, 2, "OK Lv3 block advantage is +2")
    print("\nOK Meow Boss roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
