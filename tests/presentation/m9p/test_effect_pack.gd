class_name M9PEffectPackTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var effect := EffectPresentationBinding.new()
    effect.effect_id = &"jpeg_circle_l3"
    effect.pack_type = PresentationAssetPackType.PackType.HAZARD
    effect.visual_scene = load("res://presentation/visuals/production/production_world_effect_visual.tscn") as PackedScene
    effect.visual_scale = 1.0
    t.that(effect.is_valid(), "HAZARD binding accepts arbitrary visual scene")
    t.that(PresentationAssetPackType.is_world_space(effect.pack_type), "HAZARD is a world-space Presentation pack")
    print("\nM9P EffectPack: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
