class_name ScaredCatRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/scared_cat.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(c.mechanics.successful_hit_grants_status_id, &"panic_exit", "Successful hit grants Panic Exit status")
    t.equal(r.get_move(MoveIds.ULTIMATE).on_start_effects[0].summon.id, &"husky_guardian", "Ultimate spawns Husky via SummonSystem")
    t.equal(r.get_move(MoveIds.ULTIMATE).on_start_effects[0].summon.replace_group, &"husky_guardian", "Husky is authored as a single replacement-group summon")
    print("\nScared Cat roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
