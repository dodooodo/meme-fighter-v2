class_name A5CharacterSelectTrainingTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const SELECT_MODEL_PATH := "res://frontend/character_select_model.gd"
const TRAINING_DUMMY_PATH := "res://fighter/input/training_dummy_input_source.gd"
const INPUT_FORMATTER_PATH := "res://presentation/training/input_display_formatter.gd"

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_character_select_model()
    _test_mode_and_scene_contract()
    _test_training_dummy_and_input_display()
    print("\nA5 character select/training tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_character_select_model() -> void:
    t.that(ResourceLoader.exists(SELECT_MODEL_PATH), "Character Select model exists")
    if not ResourceLoader.exists(SELECT_MODEL_PATH):
        return
    var model: Variant = load(SELECT_MODEL_PATH).new()
    t.that(bool(model.call("load_builtin_roster")), "Character Select loads manifest-backed built-in roster")
    var manifests: Array = model.call("manifests")
    t.equal(manifests.size(), 3, "Character Select exposes exactly three available fighters")
    var ids: Array[StringName] = []
    for manifest: CharacterManifest in manifests:
        ids.append(manifest.id)
        t.that(not manifest.display_name.is_empty(), "%s manifest has a display name" % String(manifest.id))
        t.that(manifest.portrait != null, "%s manifest retains a portrait asset" % String(manifest.id))
        t.that(manifest.available, "%s manifest exposes available state" % String(manifest.id))
    t.equal(ids, [&"doge", &"magic_orange_cat", &"salad_cat"], "Character Select ordering is deterministic")

func _test_mode_and_scene_contract() -> void:
    t.that("TRAINING" in BattleMode.Mode, "BattleMode exposes Training")
    t.that("TUTORIAL" in BattleMode.Mode, "BattleMode exposes Tutorial")
    var scene := load("res://frontend/mode_select_scene.tscn") as PackedScene
    t.that(scene != null, "Character Select scene loads")
    if scene == null:
        return
    var instance := scene.instantiate()
    var title := instance.get_node_or_null("Center/VBox/Title") as Label
    t.that(title != null and title.text == "Two Box Fighting", "Character Select preserves the original home title")
    t.that(instance.get_node_or_null("Center/VBox/CharacterSelectors/P1Select") is OptionButton, "Character Select preserves the original P1 picker")
    t.that(instance.get_node_or_null("Center/VBox/CharacterSelectors/P2Select") is OptionButton, "Character Select preserves the original P2 picker")
    t.that(instance.get_node_or_null("Center/VBox/Buttons/VsCpu") != null, "Character Select preserves the original CPU start")
    t.that(instance.get_node_or_null("Center/VBox/Buttons/Local2P") != null, "Character Select preserves the original local start")
    t.that(instance.get_node_or_null("Center/VBox/ExtraModes/Training") != null, "Character Select exposes Training without replacing the original controls")
    t.that(instance.get_node_or_null("Center/VBox/ExtraModes/Tutorial") != null, "Character Select exposes Tutorial without replacing the original controls")
    instance.free()

func _test_training_dummy_and_input_display() -> void:
    t.that(ResourceLoader.exists(TRAINING_DUMMY_PATH), "Training dummy InputSource exists")
    t.that(ResourceLoader.exists(INPUT_FORMATTER_PATH), "Training normalized input formatter exists")
    if not ResourceLoader.exists(TRAINING_DUMMY_PATH) or not ResourceLoader.exists(INPUT_FORMATTER_PATH):
        return
    var dummy: Variant = load(TRAINING_DUMMY_PATH).new()
    dummy.call("set_guard_mode", 1)
    var stand: InputFrame = dummy.call("sample", 1) as InputFrame
    t.that(stand.is_held(InputFrame.InputButton.GUARD), "Standing dummy guard produces canonical Guard held input")
    t.equal(stand.direction_y, 0, "Standing dummy guard remains upright")
    dummy.call("set_guard_mode", 2)
    var crouch: InputFrame = dummy.call("sample", 2) as InputFrame
    t.that(crouch.is_held(InputFrame.InputButton.GUARD), "Crouching dummy guard keeps Guard held")
    t.equal(crouch.direction_y, -1, "Crouching dummy guard produces canonical Down direction")
    dummy.call("set_guard_mode", 0)
    var neutral: InputFrame = dummy.call("sample", 3) as InputFrame
    t.equal(neutral.held_bits, 0, "Training dummy guard can be disabled")

    var formatter: Variant = load(INPUT_FORMATTER_PATH).new()
    var sample := InputFrame.new(9, -1, -1, InputFrame.InputButton.LIGHT | InputFrame.InputButton.GUARD, InputFrame.InputButton.LIGHT, 0)
    var text_value := String(formatter.call("format", sample))
    t.that(text_value.contains("↙"), "Input display renders normalized diagonal direction")
    t.that(text_value.contains("L"), "Input display renders Light")
    t.that(text_value.contains("G"), "Input display renders Guard")
