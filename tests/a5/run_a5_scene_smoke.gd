extends SceneTree

const SELECT_SCENE := preload("res://frontend/mode_select_scene.tscn")
const SCREENSHOT_PATH := "/private/tmp/a5_character_select.png"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    root.size = Vector2i(1440, 900)
    await _smoke_character_select()
    await _smoke_launch("VsCpu", BattleMode.Mode.VS_CPU, CpuInputSource)
    await _smoke_launch("Local2P", BattleMode.Mode.LOCAL_2P, KeyboardInputSource)
    await _smoke_launch("Training", BattleMode.Mode.TRAINING, TrainingDummyInputSource)
    await _smoke_launch("Tutorial", BattleMode.Mode.TUTORIAL, TrainingDummyInputSource)
    print("\nA5 scene smoke result: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
    quit(0 if _failures == 0 else 1)


func _smoke_character_select() -> void:
    var select := await _open_character_select()
    _check(select.model.count() == 4, "Character Select loads four manifest-backed fighters")
    _check(select.p1_select.item_count == 4, "Original P1 picker lists four manifest-backed fighters")
    _check(select.p2_select.item_count == 4, "Original P2 picker lists four manifest-backed fighters")
    _check(not select.vs_cpu_button.disabled, "Character Select actions are enabled after package discovery")
    await process_frame
    await process_frame
    if DisplayServer.get_name() == "headless":
        print("[SKIP] Character Select screenshot requires a rendering display; scene smoke remains valid")
    else:
        var screenshot := root.get_texture().get_image()
        _check(screenshot.save_png(SCREENSHOT_PATH) == OK, "Character Select visual regression screenshot is captured")
    await _dispose_current_scene()


func _smoke_launch(button_name: String, mode: int, expected_source_type: Variant) -> void:
    var select := await _open_character_select()
    var group := "ExtraModes" if button_name in ["Training", "Tutorial"] else "Buttons"
    var button := select.get_node("Center/VBox/%s/%s" % [group, button_name]) as Button
    _check(button != null, "%s launch action exists" % BattleMode.display_name(mode))
    if button == null:
        await _dispose_current_scene()
        return
    button.pressed.emit()
    await process_frame
    await process_frame
    var battle := current_scene as BattleScene
    _check(battle != null, "%s opens BattleScene" % BattleMode.display_name(mode))
    if battle == null:
        await _dispose_current_scene()
        return
    _check(battle.battle_mode == mode, "%s preserves selected battle mode" % BattleMode.display_name(mode))
    _check(battle.simulation != null, "%s configures the fixed-tick simulation" % BattleMode.display_name(mode))
    _check(battle.simulation.fighter_a.data.id == &"doge", "%s carries the selected P1 package" % BattleMode.display_name(mode))
    _check(battle.simulation.fighter_b.data.id == &"magic_orange_cat", "%s carries the selected P2 package" % BattleMode.display_name(mode))
    _check(is_instance_of(battle.simulation.fighter_b.input_source, expected_source_type), "%s wires the expected P2 InputSource" % BattleMode.display_name(mode))
    _check(battle.training_overlay.visible == BattleMode.uses_training_rules(mode), "%s sets Training overlay visibility" % BattleMode.display_name(mode))
    _check(battle.tutorial_overlay.visible == (mode == BattleMode.Mode.TUTORIAL), "%s sets Tutorial overlay visibility" % BattleMode.display_name(mode))
    if mode == BattleMode.Mode.VS_CPU:
        _check_doge_feet_pivot(battle)
    await _dispose_current_scene()


func _check_doge_feet_pivot(battle: BattleScene) -> void:
    var visual := battle.presentation_controller.p1_controller.visual as ProductionFighterVisual
    _check(visual != null, "Doge uses the shared production visual adapter")
    if visual == null:
        return
    var sprite := visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    _check(sprite != null and not sprite.centered, "Doge runtime sprite uses top-left pivot coordinates")
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/doge/animations/manifest.json"))
    var animations: Variant = parsed.get("animations", []) if parsed is Dictionary else []
    _check(animations is Array and not animations.is_empty(), "Doge runtime has authored feet-center frame metadata")
    if sprite == null or not (animations is Array) or animations.is_empty():
        return
    var frames: Variant = animations[0].get("frames", []) if animations[0] is Dictionary else []
    if not (frames is Array) or frames.is_empty() or not (frames[0] is Dictionary):
        _check(false, "Doge idle frame exposes a feet-center pivot")
        return
    var pivot: Variant = frames[0].get("pivot_pixels", [])
    _check(pivot is Array and pivot.size() == 2, "Doge idle frame exposes a feet-center pivot")
    if not (pivot is Array) or pivot.size() != 2:
        return
    var pivot_in_visual := sprite.transform * Vector2(float(pivot[0]), float(pivot[1]))
    _check(pivot_in_visual.length() <= 0.01, "Doge authored feet pivot maps to the fighter visual origin")


func _open_character_select() -> ModeSelectScene:
    var select := SELECT_SCENE.instantiate() as ModeSelectScene
    root.add_child(select)
    current_scene = select
    await process_frame
    return select


func _dispose_current_scene() -> void:
    if current_scene != null and is_instance_valid(current_scene):
        var previous := current_scene
        current_scene = null
        previous.queue_free()
        await process_frame


func _check(condition: bool, label: String) -> void:
    if condition:
        print("[PASS] %s" % label)
        return
    _failures += 1
    push_error("[FAIL] %s" % label)
