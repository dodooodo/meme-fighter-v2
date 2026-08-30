class_name BindingWriterTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const WRITER := preload("res://addons/character_content_inspector/binding_writer.gd")
const SALAD_CAT := "res://content/characters/salad_cat/presentation/character_presentation.tres"
const NIU_LAI := "res://content/characters/niu_lai/presentation/character_presentation.tres"

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_rebind_changes_exactly_one_line()
    _test_rebind_leaves_other_bindings_alone()
    _test_add_binding_is_a_minimal_insert()
    _test_refuses_unknown_move()
    _test_refuses_duplicate_binding()
    _test_refuses_conditioned_move()
    _test_refuses_unexpected_file_shape()
    print("\nBindingWriter tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_rebind_changes_exactly_one_line() -> void:
    var original := _read(SALAD_CAT)
    var result: Dictionary = WRITER.rebind(original, &"stand_heavy", &"crouch_low")
    t.that(result["ok"], "Rebinding a bound move succeeds")
    var changed := _changed_lines(original, result["text"])
    t.equal(changed.size(), 1, "Rebinding changes exactly one line")
    if changed.size() == 1:
        t.equal(changed[0], 'animation_key = &"crouch_low"', "The changed line is the new animation key")
    t.equal(original, _read(SALAD_CAT), "The writer does not mutate its input")

func _test_rebind_leaves_other_bindings_alone() -> void:
    var original := _read(SALAD_CAT)
    var result: Dictionary = WRITER.rebind(original, &"stand_heavy", &"crouch_low")
    var text: String = result["text"]
    # stand_light is bound to stand_light; rebinding stand_heavy must not touch it.
    t.that(text.contains('move_id = &"stand_light"'), "Other bindings survive a rebind")
    t.equal(text.count('animation_key = &"stand_light"'), original.count('animation_key = &"stand_light"'),
        "Rebinding one move leaves every other animation key untouched")

func _test_add_binding_is_a_minimal_insert() -> void:
    var original := _read(SALAD_CAT)
    var result: Dictionary = WRITER.add_binding(original, &"salad_wave_l1", &"special_neutral")
    t.that(result["ok"], "Adding a binding for an unbound move succeeds")
    var text: String = result["text"]
    t.that(text.contains('move_id = &"salad_wave_l1"'), "The new binding names the move")
    t.that(text.contains('SubResource("Move_salad_wave_l1")'), "The new binding joins the move_bindings array")
    t.equal(_load_steps(text), _load_steps(original) + 1, "Adding a binding increments load_steps")
    # Sub-resource blocks are contiguous in these files, so the insert is the
    # block's four lines; the array and header lines change in place.
    t.equal(_line_count(text), _line_count(original) + 4, "Adding a binding inserts one block and nothing else")

func _test_refuses_unknown_move() -> void:
    var result: Dictionary = WRITER.rebind(_read(SALAD_CAT), &"no_such_move", &"idle")
    t.that(not result["ok"], "Rebinding a move with no binding is refused")
    t.that(not String(result["error"]).is_empty(), "A refusal explains itself")

func _test_refuses_duplicate_binding() -> void:
    var result: Dictionary = WRITER.add_binding(_read(SALAD_CAT), &"stand_heavy", &"idle")
    t.that(not result["ok"], "Adding a binding for an already-bound move is refused")

func _test_refuses_conditioned_move() -> void:
    var text := _read(NIU_LAI)
    if text.is_empty():
        return
    # niu_lai binds several moves through Courage-conditioned variants, which
    # this writer deliberately will not touch.
    var result: Dictionary = WRITER.rebind(text, &"stand_light", &"idle")
    t.that(not result["ok"], "A move with a resource-conditioned binding is refused")

func _test_refuses_unexpected_file_shape() -> void:
    var result: Dictionary = WRITER.add_binding("[gd_resource type=\"Resource\" format=3]\n", &"stand_light", &"idle")
    t.that(not result["ok"], "A file without a move binding ext_resource is refused")

# --- helpers -----------------------------------------------------------------

func _read(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    return FileAccess.get_file_as_string(path)

func _line_count(text: String) -> int:
    return text.split("\n").size()

func _load_steps(text: String) -> int:
    var expression := RegEx.new()
    expression.compile("load_steps=(\\d+)")
    var found := expression.search(text)
    return int(found.get_string(1)) if found != null else -1

func _changed_lines(before: String, after: String) -> PackedStringArray:
    var before_lines := before.split("\n")
    var after_lines := after.split("\n")
    var changed := PackedStringArray()
    if before_lines.size() != after_lines.size():
        return changed
    for index in range(before_lines.size()):
        if before_lines[index] != after_lines[index]:
            changed.append(after_lines[index])
    return changed
