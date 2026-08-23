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
    _check(select.model.count() == 3, "Character Select builds exactly three manifest-backed cards")
    _check(select.roster_container.get_child_count() == 3, "Character Select card nodes enter the live scene tree")
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
    var button := select.get_node("Margin/Layout/Actions/%s" % button_name) as Button
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
    await _dispose_current_scene()


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
