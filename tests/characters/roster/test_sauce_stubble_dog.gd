class_name SauceStubbleDogRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/sauce_stubble_dog.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    t.equal(c.mechanics.statuses[0].id, &"sauce", "Sauce debuff is a timed status")
    t.equal(r.get_move(&"sauce_shot_l1").projectile_spawns.size(), 1, "Sauce Special uses real ProjectileData")
    var expected_levels := {&"sauce_shot_l1": [120, 860], &"sauce_shot_l2": [180, 820], &"sauce_shot_l3": [240, 780]}
    for move_id: StringName in expected_levels:
        var status := r.get_move(move_id).projectile_spawns[0].projectile_data.on_hit_effects[0].status
        var expected: Array = expected_levels[move_id]
        t.equal(status.duration_frames, expected[0], "%s authors canonical Sticky duration" % move_id)
        t.equal(status.walk_speed_permille, expected[1], "%s authors canonical Sticky walk multiplier" % move_id)
        t.equal(status.dash_speed_permille, expected[1], "%s authors canonical Sticky dash multiplier" % move_id)
        t.equal(status.backstep_speed_permille, expected[1], "%s authors canonical Sticky backstep multiplier" % move_id)
    t.equal(r.get_move(MoveIds.ULTIMATE).on_start_effects[0].sequence.steps.size(), 6, "Sauce Ultimate authors four passes plus two mutually-exclusive finals")
    print("\nSauce Stubble Dog roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
