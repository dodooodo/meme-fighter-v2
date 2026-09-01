class_name NiuLaiRosterTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const MANIFEST_PATH := "res://content/characters/niu_lai/character_manifest.tres"
const ANIMATION_MANIFEST_PATH := "res://assets/characters/niu_lai/animations/manifest.json"

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_gameplay_contract()
    _test_package_and_production_art()
    _test_courage_driven_animation_variants()
    print("\nNiu Lai roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _manifest() -> CharacterManifest:
    return load(MANIFEST_PATH) as CharacterManifest if ResourceLoader.exists(MANIFEST_PATH) else null

func _test_gameplay_contract() -> void:
    var manifest := _manifest()
    t.that(manifest != null and manifest.is_valid(), "Niu Lai package manifest validates")
    if manifest == null:
        return
    var c := manifest.gameplay_resource
    var r := MoveRegistry.new()
    r.configure(c.move_set)
    t.equal(c.mechanics.resources[0].max_value, 3, "Niu Courage range is 0..3")
    t.equal(c.mechanics.heavy_knockdown_resource_id, &"", "Heavy Knockdown does not tax Courage")
    t.equal(r.get_move(MoveIds.STAND_HEAVY).cancel_windows[0].resource_condition_id, &"courage", "Heavy->Special cancel is Courage-gated by generic window data")
    t.equal(RosterRegistry.character_by_id(&"niu_lai"), c, "Compatibility roster routes Niu Lai through package gameplay")
    t.equal(RosterRegistry.presentation_by_id(&"niu_lai"), manifest.presentation_resource, "Compatibility roster routes Niu Lai through package presentation")
    for move: MoveData in c.move_set.moves:
        t.that(move.resource_path.begins_with("res://content/characters/niu_lai/gameplay/moves/"), "%s is package-owned MoveData" % String(move.id))

func _test_package_and_production_art() -> void:
    var manifest := _manifest()
    if manifest == null:
        return
    t.that(manifest.portrait != null, "Niu Lai package owns a selectable portrait")
    var presentation := manifest.presentation_resource
    t.that(presentation != null and presentation.fighter_visual_scene != null, "Niu Lai package loads production presentation")
    if presentation == null or presentation.fighter_visual_scene == null:
        return
    t.that(presentation.fighter_visual_scene.resource_path.contains("visuals/production"), "Niu Lai uses a production fighter visual")
    t.that(not presentation.fighter_visual_scene.resource_path.contains("greybox"), "Niu Lai no longer uses greybox presentation")
    t.equal(presentation.move_bindings.size(), 19, "Niu Lai binds base and Courage-specific move variants")

    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANIMATION_MANIFEST_PATH))
    t.that(parsed is Dictionary, "Niu Lai animation manifest is valid JSON")
    if not (parsed is Dictionary):
        return
    t.equal(String(parsed.get("pivot_convention", "")), "FEET_CENTER", "Niu Lai uses feet-center body pivots")
    t.equal(int(parsed.get("source_frame_count", 0)), 112, "All 112 recovered Niu Lai frames are inventoried")
    var paths: Dictionary = {}
    var keys: Dictionary = {}
    for animation: Variant in parsed.get("animations", []):
        if not (animation is Dictionary):
            continue
        keys[StringName(String(animation.get("key", "")))] = true
        for frame: Variant in animation.get("frames", []):
            if frame is Dictionary:
                paths[String(frame.get("path", ""))] = true
    t.equal(paths.size(), 112, "Every recovered Niu Lai frame is represented in the animation manifest")
    for required_key: StringName in [&"idle", &"walk_forward", &"guard_stand", &"stand_light", &"stand_heavy", &"crouch_low", &"air_attack", &"ground_throw", &"niu_special_l1", &"niu_special_l2", &"niu_special_l3", &"ultimate"]:
        t.that(keys.has(required_key), "Niu Lai animation manifest includes %s" % String(required_key))
    for path: String in paths:
        t.that(ResourceLoader.exists(path), "Niu Lai frame exists: %s" % path)

func _test_courage_driven_animation_variants() -> void:
    var manifest := _manifest()
    if manifest == null:
        return
    var fighter := Fighter.new()
    fighter.configure(1, manifest.gameplay_resource, Vector2i(50000, 56000), 8000, 120000, 56000)
    fighter.state_machine.state = FighterStateMachine.State.IDLE
    t.equal(FighterPresentationResolver.resolve_animation(fighter, manifest.presentation_resource), &"idle", "Courage 0 uses timid idle")
    fighter.resources.set_value(&"courage", 3)
    t.equal(FighterPresentationResolver.resolve_animation(fighter, manifest.presentation_resource), &"idle_courage_3", "Courage 3 uses warrior idle")

    fighter.state_machine.state = FighterStateMachine.State.GROUND_ATTACK
    fighter.move_runner.start_move(fighter.move_registry.get_move(MoveIds.STAND_HEAVY))
    fighter.resources.set_value(&"courage", 0)
    t.equal(FighterPresentationResolver.resolve_animation(fighter, manifest.presentation_resource), &"stand_heavy", "Courage 0 uses base Heavy art")
    fighter.resources.set_value(&"courage", 2)
    t.equal(FighterPresentationResolver.resolve_animation(fighter, manifest.presentation_resource), &"stand_heavy_courage_2", "Courage 2 uses forward-step Heavy art")
