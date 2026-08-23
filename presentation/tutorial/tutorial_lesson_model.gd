# Presentation-only tutorial progress over normalized input facts.
class_name TutorialLessonModel
extends RefCounted

const LESSON_IDS: Array[StringName] = [
    &"movement",
    &"guard",
    &"light_heavy",
    &"throw",
    &"special",
    &"ultimate",
]

const TITLES := {
    &"movement": "MOVE",
    &"guard": "GUARD",
    &"light_heavy": "LIGHT + HEAVY",
    &"throw": "THROW",
    &"special": "SPECIAL",
    &"ultimate": "ULTIMATE",
}

const PROMPTS := {
    &"movement": "Use A / D to move. Tap W to jump.",
    &"guard": "Hold J to guard. Add S to guard low.",
    &"light_heavy": "Press U for Light, then I for Heavy.",
    &"throw": "Hold Forward and press I near the dummy.",
    &"special": "Press and hold K, then release to charge Special.",
    &"ultimate": "When the meter is full, press L for Ultimate.",
}

var _index: int = 0
var _saw_light: bool = false
var _saw_heavy: bool = false

func lesson_ids() -> Array[StringName]:
    return LESSON_IDS.duplicate()

func current_lesson_id() -> StringName:
    return &"complete" if is_complete() else LESSON_IDS[_index]

func current_title() -> String:
    return "TRAINING COMPLETE" if is_complete() else String(TITLES[current_lesson_id()])

func current_prompt() -> String:
    return "You know the essentials. Press R to run it again." if is_complete() else String(PROMPTS[current_lesson_id()])

func progress_text() -> String:
    return "%d / %d" % [mini(_index + 1, LESSON_IDS.size()), LESSON_IDS.size()]

func is_complete() -> bool:
    return _index >= LESSON_IDS.size()

func reset() -> void:
    _index = 0
    _saw_light = false
    _saw_heavy = false

func observe_input(frame: InputFrame, facing: int) -> bool:
    if frame == null or is_complete():
        return false
    var completed := false
    match current_lesson_id():
        &"movement":
            completed = frame.direction_x != 0 or frame.direction_y > 0
        &"guard":
            completed = frame.is_held(InputFrame.InputButton.GUARD)
        &"light_heavy":
            _saw_light = _saw_light or frame.is_pressed(InputFrame.InputButton.LIGHT)
            _saw_heavy = _saw_heavy or frame.is_pressed(InputFrame.InputButton.HEAVY)
            completed = _saw_light and _saw_heavy
        &"throw":
            var forward := -1 if facing < 0 else 1
            completed = frame.direction_x == forward and frame.is_pressed(InputFrame.InputButton.HEAVY)
        &"special":
            completed = frame.is_pressed(InputFrame.InputButton.SPECIAL)
        &"ultimate":
            completed = frame.is_pressed(InputFrame.InputButton.ULTIMATE)
    if completed:
        _index += 1
    return completed
