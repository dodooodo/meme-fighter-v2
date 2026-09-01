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
    t.that(bool(model.call("load_builtin_roster")), "Character Select loads the registry-backed built-in roster")
    var entries: Array = model.call("entries")
    t.equal(entries.size(), 14, "Character Select exposes all fourteen canonical fighters")
    var ids: Array[StringName] = []
    for index in range(entries.size()):
        var frontend_entry: Dictionary = entries[index]
        var roster_entry := RosterRegistry.entry(index)
        var id := frontend_entry["id"] as StringName
        ids.append(id)
        t.that(not String(frontend_entry["display_name"]).is_empty(), "%s frontend entry has a display name" % String(id))
        t.that(frontend_entry["character"] == roster_entry["character"], "%s frontend uses the registry CharacterData object" % String(id))
        t.that(frontend_entry["presentation"] == roster_entry["presentation"], "%s frontend uses the registry presentation object" % String(id))
        t.equal(model.call("index_for_id", id), index, "%s stable ID resolves to its authored roster index" % String(id))
    t.equal(ids, [&"alien_meow", &"doge", &"ya_mouse", &"tempura_penguin", &"goblin_love", &"salad_cat", &"magic_orange_cat", &"blade_shield", &"pink_star", &"sauce_stubble_dog", &"scared_cat", &"ok_meow_boss", &"niu_lai", &"bao_la"], "Character Select preserves deterministic RosterRegistry order")
    var unique_ids: Dictionary = {}
    for id: StringName in ids:
        unique_ids[id] = true
    t.equal(unique_ids.size(), 14, "Character Select contains no duplicate character IDs")
    for id: StringName in [&"doge", &"salad_cat", &"magic_orange_cat", &"niu_lai"]:
        var package_entry: Dictionary = entries[int(model.call("index_for_id", id))]
        t.equal(package_entry["source_type"], "PACKAGE", "%s retains package-backed metadata" % String(id))
        var manifest := package_entry["manifest"] as CharacterManifest
        t.that(manifest != null and manifest.gameplay_resource == package_entry["character"], "%s package metadata points to the authoritative CharacterData" % String(id))
    for id: StringName in [&"alien_meow", &"ya_mouse", &"tempura_penguin", &"goblin_love", &"blade_shield", &"pink_star", &"sauce_stubble_dog", &"scared_cat", &"ok_meow_boss", &"bao_la"]:
        var legacy_entry: Dictionary = entries[int(model.call("index_for_id", id))]
        t.equal(legacy_entry["source_type"], "LEGACY", "%s remains on its active legacy resource" % String(id))
        t.that(legacy_entry["manifest"] == null, "%s does not gain a shadow gameplay manifest" % String(id))

func _test_mode_and_scene_contract() -> void:
    t.that("TRAINING" in BattleMode.Mode, "BattleMode exposes Training")
    t.that("TUTORIAL" in BattleMode.Mode, "BattleMode exposes Tutorial")
    var scene := load("res://frontend/mode_select_scene.tscn") as PackedScene
    t.that(scene != null, "Character Select scene loads")
    if scene == null:
        return
    var instance := scene.instantiate()
    var title := instance.get_node_or_null("Center/VBox/Title") as Label
    t.that(title != null and title.text == "Meme Fighter V2", "Character Select presents the player-facing game title")
    t.that(instance.get_node_or_null("Center/VBox/CharacterSelectors/P1Select") is OptionButton, "Character Select preserves the original P1 picker")
    t.that(instance.get_node_or_null("Center/VBox/CharacterSelectors/P2Select") is OptionButton, "Character Select preserves the original P2 picker")
    t.that(instance.get_node_or_null("Center/VBox/SelectionSummary") is Label, "Character Select displays live P1/P2 selection confirmation")
    var controls := instance.get_node_or_null("Center/VBox/Controls") as Label
    t.that(controls != null and controls.text.contains("Low") and controls.text.contains("Throw") and not controls.text.contains("F1-F5"), "Character Select exposes concise player controls without debug navigation")
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
