class_name M9PHazardVisualPackTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var data := CharacterPresentationData.new()
    data.character_id = &"zone_fighter"
    data.display_name = "Magic"
    var binding := EffectPresentationBinding.new()
    binding.effect_id = &"jpeg_circle_l3"
    binding.pack_type = PresentationAssetPackType.PackType.HAZARD
    binding.visual_scene = load("res://presentation/visuals/production/production_world_effect_visual.tscn") as PackedScene
    data.effect_bindings = [binding]
    var presenter := WorldEffectPresenter.new()
    var presentations: Array[CharacterPresentationData] = [data]
    presenter.configure(presentations)
    var spawned := presenter.present_effect(&"zone_fighter", &"jpeg_circle_l3", Vector2(320, 500), 1)
    t.that(spawned != null, "HAZARD visual spawns independently of Fighter sprite dimensions")
    t.equal(spawned.global_position, Vector2(320, 500), "HAZARD visual uses supplied world position")
    presenter.free()
    print("\nM9P HazardVisualPack: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
