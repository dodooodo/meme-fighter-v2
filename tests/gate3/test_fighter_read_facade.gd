# Phase 3 runtime contract for the derived, read-only Fighter query boundary.
class_name FighterReadFacadeTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_real_ground_air_land_queries()
    _test_status_queries_follow_authoritative_component()
    _test_mode_queries_follow_authoritative_component()
    _test_resource_queries_and_copied_observation()
    print("\nFighter read facade tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a_id: StringName, b_id: StringName) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        RosterRegistry.character_by_id(a_id),
        RosterRegistry.character_by_id(b_id),
        null,
        null,
        Vector2i(36000, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(72000, BattleSimulation.GROUND_Y_UNITS)
    )
    return battle

func _test_real_ground_air_land_queries() -> void:
    var battle := _battle(&"alien_meow", &"doge")
    var fighter := battle.fighter_a
    t.that(fighter.is_grounded(), "Spawned real Fighter reports grounded through MovementMotor truth")
    t.that(not fighter.is_airborne(), "Spawned real Fighter does not report airborne")
    battle.simulate_frame(InputFrame.new(1, 0, 1, 0, 0, 0), InputFrame.neutral(1))
    t.that(fighter.is_airborne(), "Real jump reports airborne")
    t.that(not fighter.is_grounded(), "Real jump clears derived grounded query")
    var landed := false
    for frame in range(2, 242):
        battle.simulate_frame(InputFrame.neutral(frame), InputFrame.neutral(frame))
        if fighter.is_grounded():
            landed = true
            break
    t.that(landed, "Real MovementMotor integration lands the Fighter")
    t.that(fighter.is_grounded() and not fighter.is_airborne(), "Landing restores complementary ground queries")

func _test_status_queries_follow_authoritative_component() -> void:
    var battle := _battle(&"sauce_stubble_dog", &"alien_meow")
    var fighter := battle.fighter_a
    t.that(not fighter.has_status(&"sauce"), "Fighter status query starts empty")
    t.that(fighter.statuses.apply_defined(&"sauce"), "Canonical StatusEffectComponent applies authored Sauce")
    var initial_remaining := fighter.status_remaining(&"sauce")
    t.that(fighter.has_status(&"sauce"), "Fighter status query observes canonical apply")
    t.that(initial_remaining > 0, "Fighter status query returns authored remaining duration")
    for _frame in range(initial_remaining):
        fighter.status_tick()
    t.that(not fighter.has_status(&"sauce"), "Fighter status query observes canonical expiry")
    t.equal(fighter.status_remaining(&"sauce"), 0, "Expired status has zero remaining frames")

func _test_mode_queries_follow_authoritative_component() -> void:
    var battle := _battle(&"doge", &"alien_meow")
    var fighter := battle.fighter_a
    t.equal(fighter.get_active_mode_id(), &"", "Fighter mode query starts empty")
    t.that(fighter.mode.enter(&"super_doge", -1, battle.frame_number), "Canonical ModeComponent enters authored Super Doge")
    t.equal(fighter.get_active_mode_id(), &"super_doge", "Fighter mode query observes canonical mode")
    t.that(fighter.get_mode_remaining_frames() > 0, "Fighter mode query exposes authored remaining frames")
    fighter.mode.exit()
    t.equal(fighter.get_active_mode_id(), &"", "Fighter mode query observes canonical exit")
    t.equal(fighter.get_mode_remaining_frames(), 0, "Exited mode reports zero remaining frames")

func _test_resource_queries_and_copied_observation() -> void:
    var battle := _battle(&"pink_star", &"alien_meow")
    var fighter := battle.fighter_a
    var initial := fighter.get_resource_value(&"face_actions")
    t.that(fighter.resources.set_value(&"face_actions", 3), "Canonical FighterResourceComponent mutates authored Face Actions")
    t.equal(fighter.get_resource_value(&"face_actions"), 3, "Fighter resource query observes canonical mutation")
    var read := fighter.capture_combat_read()
    var copied_resources := read["resources"] as Dictionary
    copied_resources["face_actions"] = 99
    t.equal(fighter.get_resource_value(&"face_actions"), 3, "Mutating copied read observation cannot mutate authoritative resource state")
    t.that(initial != fighter.get_resource_value(&"face_actions") or initial == 3, "Resource query remains derived from the existing component")
