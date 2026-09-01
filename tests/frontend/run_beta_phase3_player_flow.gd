# Beta Phase 3 player-facing flow smoke.  It deliberately uses ModeSelect's
# real buttons and BattleScene's input/event path; HP/contact are fixtures only
# to reach the authored KO and match-end UI in a bounded test time.
extends SceneTree

const MODE_SELECT_SCENE := preload("res://frontend/mode_select_scene.tscn")

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var select := await _open_select()
    if select != null:
        _verify_character_select(select)
        var battle := await _start_local_match(select)
        if battle != null:
            await _verify_match_end_and_navigation(battle)
    print("\nBeta Phase 3 player-facing flow: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)

func _open_select() -> ModeSelectScene:
    var select := MODE_SELECT_SCENE.instantiate() as ModeSelectScene
    _check(select != null, "Launch opens the real Mode Select scene")
    if select == null:
        return null
    root.add_child(select)
    current_scene = select
    await process_frame
    return select

func _verify_character_select(select: ModeSelectScene) -> void:
    _check(select.p1_select.item_count == 14 and select.p2_select.item_count == 14, "All 14 fighters are visible to both P1 and P2")
    _check(select.get_viewport().gui_get_focus_owner() == select.p1_select, "Mode Select gives initial keyboard focus to P1 selection")
    var controls := select.get_node_or_null("Center/VBox/Controls") as Label
    _check(controls != null and controls.text.contains("Low") and controls.text.contains("Throw") and controls.text.contains("Ultimate"), "Player-facing controls explain movement, attacks, Guard, Throw, Special and Ultimate")
    var pink_index := select.model.index_for_id(&"pink_star")
    var bao_index := select.model.index_for_id(&"bao_la")
    select.p1_select.select(pink_index)
    select.p2_select.select(bao_index)
    select.p1_select.item_selected.emit(pink_index)
    select.p2_select.item_selected.emit(bao_index)
    var pink_name := String(select.model.entry(pink_index).get("display_name", ""))
    var bao_name := String(select.model.entry(bao_index).get("display_name", ""))
    _check(select.selection_summary.text.contains(pink_name) and select.selection_summary.text.contains(bao_name), "P1/P2 selection confirmation updates with both chosen fighter names")

func _start_local_match(select: ModeSelectScene) -> BattleScene:
    select.local_button.pressed.emit()
    await process_frame
    await process_frame
    var battle := current_scene as BattleScene
    _check(battle != null, "Confirmed 2P Local selection launches a real BattleScene")
    if battle != null:
        _check(battle.simulation != null and battle.simulation.fighter_a.data.id == &"pink_star" and battle.simulation.fighter_b.data.id == &"bao_la", "Selected CharacterData reaches BattleScene unchanged")
    return battle

func _verify_match_end_and_navigation(scene: BattleScene) -> void:
    var battle := scene.simulation
    await _win_two_rounds(scene)
    _check(battle.round_controller.state == RoundController.State.MATCH_OVER, "Two real KOs complete the match through RoundController")
    var prompt := scene.get_node_or_null("CanvasLayer/PostMatchPrompt") as Label
    _check(prompt != null and prompt.visible and prompt.text.contains("REMATCH") and prompt.text.contains("CHARACTER SELECT"), "Match end clearly exposes rematch and return controls")

    scene._unhandled_key_input(_key_press(KEY_R))
    await process_frame
    _check(scene.simulation != null and scene.simulation.round_controller.state == RoundController.State.ROUND_ACTIVE and prompt != null and not prompt.visible, "R rematches without editor intervention and clears the match-end prompt")

    scene._unhandled_key_input(_key_press(KEY_ESCAPE))
    await process_frame
    await process_frame
    var returned := current_scene as ModeSelectScene
    _check(returned != null, "ESC returns from BattleScene to player-facing character select")
    if returned != null:
        _check(returned.p1_select.item_count == 14 and returned.p2_select.item_count == 14, "Returned character select remains fully populated")
        returned.queue_free()
        current_scene = null

func _win_two_rounds(scene: BattleScene) -> void:
    for _round in range(2):
        var battle := scene.simulation
        _place_at_contact(battle)
        battle.fighter_b.combatant.hp = 1
        _tick_scene(scene, InputFrame.with_light_press(battle.frame_number + 1))
        for _i in range(8):
            _tick_scene(scene)
        _check(battle.fighter_b.combatant.is_ko, "Real Light input causes a KO for the post-match flow")
        for _i in range(battle.round_controller.rules.post_round_frames):
            _tick_scene(scene)

func _place_at_contact(battle: BattleSimulation) -> void:
    battle.fighter_a.movement_motor.sim_position = Vector2i(50000, BattleSimulation.GROUND_Y_UNITS)
    battle.fighter_b.movement_motor.sim_position = Vector2i(55000, BattleSimulation.GROUND_Y_UNITS)
    battle.fighter_a.movement_motor.facing = 1
    battle.fighter_b.movement_motor.facing = -1

func _tick_scene(scene: BattleScene, p1: InputFrame = null, p2: InputFrame = null) -> void:
    var battle := scene.simulation
    var frame := battle.frame_number + 1
    battle.simulate_frame(p1 if p1 != null else InputFrame.neutral(frame), p2 if p2 != null else InputFrame.neutral(frame))
    scene._consume_simulation_events(battle.drain_events())

func _key_press(keycode: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    return event

func _check(condition: bool, label: String) -> void:
    if condition:
        print("[PASS] %s" % label)
        return
    failures += 1
    push_error("[FAIL] %s" % label)
