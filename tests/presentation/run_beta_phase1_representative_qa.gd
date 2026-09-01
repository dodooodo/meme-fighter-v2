# Beta Phase 1 representative frontend -> BattleScene presentation smoke.
# Inputs travel through real BattleSimulation; the assertions inspect only
# presentation-controller output after the authoritative frame resolves.
extends SceneTree

const MODE_SELECT_SCENE := preload("res://frontend/mode_select_scene.tscn")
const SPECIAL := InputFrame.InputButton.SPECIAL
const MATCHES: Array[Dictionary] = [
    {"p1": &"doge", "p2": &"alien_meow"},
    {"p1": &"pink_star", "p2": &"bao_la"},
    {"p1": &"tempura_penguin", "p2": &"magic_orange_cat"},
    {"p1": &"blade_shield", "p2": &"niu_lai"},
    {"p1": &"goblin_love", "p2": &"ok_meow_boss"},
    {"p1": &"scared_cat", "p2": &"sauce_stubble_dog"},
]

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    for match: Dictionary in MATCHES:
        var label := "%s vs %s" % [String(match["p1"]), String(match["p2"])]
        var scene := await _open_match(match["p1"] as StringName, match["p2"] as StringName)
        _check(scene != null, "%s opens in real BattleScene" % label)
        if scene != null:
            _exercise_visual_actions(scene, label)
            await _close_scene(scene)
    print("\nBeta Phase 1 representative presentation QA: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)

func _exercise_visual_actions(scene: BattleScene, label: String) -> void:
    var battle := scene.simulation
    _check(battle != null and scene.presentation_controller.configured, "%s presentation is configured" % label)
    if battle == null:
        return
    _tick(scene, InputFrame.new(battle.frame_number + 1, 1))
    _check(scene.presentation_controller.p1_controller.current_animation_key != &"", "%s walk has a visible animation" % label)
    _tick(scene, InputFrame.with_light_press(battle.frame_number + 1))
    _check(scene.presentation_controller.p1_controller.current_animation_key != &"", "%s Light has a visible animation" % label)
    _wait_for_idle(scene)
    for held_frame in range(3):
        _tick(scene, InputFrame.new(battle.frame_number + 1, 0, 0, SPECIAL, SPECIAL if held_frame == 0 else 0, 0))
    _tick(scene, InputFrame.new(battle.frame_number + 1, 0, 0, 0, 0, SPECIAL))
    _check(battle.fighter_a.move_runner.current_move_id().ends_with("_l1") and scene.presentation_controller.p1_controller.current_animation_key != &"",
        "%s Special Lv1 has a visible animation" % label)
    _wait_for_idle(scene)
    battle.fighter_a.meter.set_value(100)
    _tick(scene, InputFrame.with_ultimate_press(battle.frame_number + 1))
    _check(battle.fighter_a.move_runner.current_move_id() == &"ultimate" and scene.presentation_controller.p1_controller.current_animation_key != &"",
        "%s Ultimate has a visible animation" % label)

func _tick(scene: BattleScene, p1: InputFrame) -> void:
    var battle := scene.simulation
    battle.simulate_frame(p1, InputFrame.neutral(battle.frame_number + 1))
    scene._consume_simulation_events(battle.drain_events())
    scene.presentation_controller.sync_from_simulation()

func _wait_for_idle(scene: BattleScene, max_frames: int = 120) -> void:
    var battle := scene.simulation
    for _i in range(max_frames):
        if not battle.fighter_a.move_runner.is_running() and battle.fighter_a.state_machine.state == FighterStateMachine.State.IDLE:
            return
        _tick(scene, InputFrame.neutral(battle.frame_number + 1))

func _open_match(p1_id: StringName, p2_id: StringName) -> BattleScene:
    var select := MODE_SELECT_SCENE.instantiate() as ModeSelectScene
    if select == null:
        return null
    root.add_child(select)
    current_scene = select
    await process_frame
    select.p1_select.select(select.model.index_for_id(p1_id))
    select.p2_select.select(select.model.index_for_id(p2_id))
    select.local_button.pressed.emit()
    await process_frame
    await process_frame
    return current_scene as BattleScene

func _close_scene(scene: Node) -> void:
    if scene != null and is_instance_valid(scene):
        current_scene = null
        scene.queue_free()
        await process_frame

func _check(condition: bool, label: String) -> void:
    if condition:
        print("[PASS] %s" % label)
    else:
        failures += 1
        push_error("[FAIL] %s" % label)
