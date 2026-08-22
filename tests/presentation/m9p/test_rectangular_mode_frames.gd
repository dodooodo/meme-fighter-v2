class_name M9PRectangularModeFrameTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var frames := SpriteFrames.new()
    frames.add_animation(&"mode_test")
    var tall := ImageTexture.create_from_image(Image.create(96, 160, false, Image.FORMAT_RGBA8))
    var wide := ImageTexture.create_from_image(Image.create(180, 104, false, Image.FORMAT_RGBA8))
    frames.add_frame(&"mode_test", tall)
    frames.add_frame(&"mode_test", wide)
    t.equal(frames.get_frame_count(&"mode_test"), 2, "MODE_FIGHTER SpriteFrames accepts variable frame count")
    t.that(frames.get_frame_texture(&"mode_test", 0).get_width() != frames.get_frame_texture(&"mode_test", 0).get_height(), "Tall rectangular frame remains rectangular")
    t.that(frames.get_frame_texture(&"mode_test", 1).get_width() != frames.get_frame_texture(&"mode_test", 1).get_height(), "Wide rectangular frame remains rectangular")
    print("\nM9P RectangularModeFrames: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
