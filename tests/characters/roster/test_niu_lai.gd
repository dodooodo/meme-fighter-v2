class_name NiuLaiRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/niu_lai.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(c.mechanics.resources[0].max_value, 3, "Niu Courage range is 0..3")
    t.equal(c.mechanics.heavy_knockdown_resource_id, &"courage", "Heavy Knockdown decrements Courage generically")
    t.equal(r.get_move(MoveIds.STAND_HEAVY).cancel_windows[0].resource_condition_id, &"courage", "Heavy->Special cancel is Courage-gated by generic window data")
    print("\nNiu Lai roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
