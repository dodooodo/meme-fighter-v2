class_name SaladCatRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := RosterRegistry.character_by_id(&"salad_cat")
    var r := MoveRegistry.new(); r.configure(c.move_set)
    var low_positioning := r.get_move(MoveIds.CROUCH_LOW).on_hit_effects[0].positioning
    t.that(low_positioning != null, "Salad Low has authored outward positioning")
    t.equal(low_positioning.type, PositioningEffectData.Type.PUSH_TO_MINIMUM_SEPARATION, "Salad Low uses never-pull minimum-separation positioning")
    t.equal(r.get_move(MoveIds.GROUND_THROW).throw_positioning.type, PositioningEffectData.Type.PUSH_TO_MINIMUM_SEPARATION, "Salad Throw uses never-pull minimum-separation positioning")
    t.equal(r.get_move(MoveIds.ULTIMATE).on_complete_effects[0].positioning.type, PositioningEffectData.Type.PUSH_TO_MINIMUM_SEPARATION, "Salad Ultimate reset uses never-pull minimum-separation positioning")
    t.that(r.get_move(MoveIds.ULTIMATE).on_start_effects[0].sequence.steps.size() == 3, "Salad Ultimate is authored High/Low sequence")
    print("\nSalad Cat roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
