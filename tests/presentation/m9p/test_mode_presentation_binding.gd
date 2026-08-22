class_name M9PModePresentationBindingTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var data := CharacterPresentationData.new()
    data.character_id = &"rush_grappler"
    data.display_name = "Doge"
    var binding := ModePresentationBinding.new()
    binding.mode_id = &"super_doge"
    binding.fighter_visual_scene = load("res://presentation/visuals/greybox_fighter_visual.tscn") as PackedScene
    binding.visual_scale = 1.2
    data.mode_bindings = [binding]
    t.equal(data.validate(&"rush_grappler").size(), 0, "MODE_FIGHTER binding validates without gameplay dependency")
    data.rebuild_cache()
    t.equal(data.mode_binding(&"super_doge"), binding, "Mode lookup resolves stable mode id")
    print("\nM9P ModePresentationBinding: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
