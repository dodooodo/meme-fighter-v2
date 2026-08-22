class_name A5TutorialModelTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const MODEL_PATH := "res://presentation/tutorial/tutorial_lesson_model.gd"
const EXPECTED_LESSONS: Array[StringName] = [
    &"movement",
    &"guard",
    &"light_heavy",
    &"throw",
    &"special",
    &"ultimate",
]

var t = ASSERT_HELPER.new()

func run_all() -> int:
    t.that(ResourceLoader.exists(MODEL_PATH), "Tutorial lesson model exists")
    if not ResourceLoader.exists(MODEL_PATH):
        return t.failed
    var model: Variant = load(MODEL_PATH).new()
    t.equal(model.call("lesson_ids"), EXPECTED_LESSONS, "Tutorial teaches exactly the six roadmap topics and seven actions")
    t.equal(model.call("current_lesson_id"), &"movement", "Tutorial starts with movement")
    _observe(model, InputFrame.new(1, 1, 0, 0, 0, 0))
    t.equal(model.call("current_lesson_id"), &"guard", "Movement input advances to Guard")
    _observe(model, _button_frame(2, InputFrame.InputButton.GUARD))
    t.equal(model.call("current_lesson_id"), &"light_heavy", "Guard input advances to Light/Heavy")
    _observe(model, _button_frame(3, InputFrame.InputButton.LIGHT))
    t.equal(model.call("current_lesson_id"), &"light_heavy", "Light/Heavy lesson waits for both attacks")
    _observe(model, _button_frame(4, InputFrame.InputButton.HEAVY))
    t.equal(model.call("current_lesson_id"), &"throw", "Light and Heavy together complete the attack lesson")
    _observe(model, InputFrame.new(5, 1, 0, InputFrame.InputButton.HEAVY, InputFrame.InputButton.HEAVY, 0), 1)
    t.equal(model.call("current_lesson_id"), &"special", "Facing-relative Forward + Heavy advances Throw")
    _observe(model, _button_frame(6, InputFrame.InputButton.SPECIAL))
    t.equal(model.call("current_lesson_id"), &"ultimate", "Special input advances to Ultimate")
    _observe(model, _button_frame(7, InputFrame.InputButton.ULTIMATE))
    t.that(bool(model.call("is_complete")), "Ultimate input completes the minimum tutorial")
    model.call("reset")
    t.equal(model.call("current_lesson_id"), &"movement", "Tutorial reset returns to first lesson")
    print("\nA5 tutorial tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _observe(model: Variant, input: InputFrame, facing: int = 1) -> void:
    model.call("observe_input", input, facing)

func _button_frame(frame: int, button: int) -> InputFrame:
    return InputFrame.new(frame, 0, 0, button, button, 0)
