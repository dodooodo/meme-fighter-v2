class_name GoblinLoveRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/goblin_love.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(r.get_move(&"goblin_grab_l1").throw_kind, MoveData.ThrowKind.COMMAND_GRAB, "Goblin Special is command grab")
    t.equal(r.get_move(&"goblin_grab_l1").startup_frames, 7, "Goblin Lv1 grab startup is 7F")
    t.equal(r.get_move(&"goblin_grab_l2").startup_frames, 9, "Goblin Lv2 grab startup is 9F")
    t.equal(r.get_move(&"goblin_grab_l3").startup_frames, 12, "Goblin Lv3 grab startup is 12F")
    t.equal(c.mechanics.modes[0].mode_id, &"love_awakened", "Goblin awakened mode is generic ModeData")
    print("\nGoblin Love roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
