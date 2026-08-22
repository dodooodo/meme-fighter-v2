class_name M9PUltimateScreenAspectTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var scene := load("res://presentation/ultimates/ultimate_screen_visual.tscn") as PackedScene
    var visual := scene.instantiate() as UltimateScreenVisual
    var rect := visual.get_node("TextureRect") as TextureRect
    t.equal(rect.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Ultimate screen visual uses aspect-preserving cover")
    t.near(rect.anchor_right, 1.0, 0.001, "Ultimate screen TextureRect fills viewport width")
    t.near(rect.anchor_bottom, 1.0, 0.001, "Ultimate screen TextureRect fills viewport height")
    visual.free()
    print("\nM9P UltimateScreenAspect: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
