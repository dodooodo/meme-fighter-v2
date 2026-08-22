class_name BaoLaRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/bao_la.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.that(r.get_move(&"bao_counter_l3").counter_data != null, "Bao Lv3 owns release CounterData")
    t.equal(c.mechanics.last_stand_mode_id, &"last_stand", "Bao Last Stand is authoritative ModeData")
    t.equal(c.mechanics.last_stand_expiry_move_ids.size(), 4, "Bao resolve maps to four deterministic expiry outcomes")
    print("\nBao La roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
