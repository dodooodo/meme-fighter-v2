# Beta Phase 1 real frontend -> BattleScene presentation smoke for all 14 roster entries.
# The script observes BattleScene's existing presentation controller; it never
# lets a visual result influence simulation state or inputs.
extends SceneTree

const MODE_SELECT_SCENE := preload("res://frontend/mode_select_scene.tscn")
const STATE_SAMPLES: Array[int] = [
    FighterStateMachine.State.IDLE,
    FighterStateMachine.State.WALK_FORWARD,
    FighterStateMachine.State.JUMP,
    FighterStateMachine.State.GUARD,
    FighterStateMachine.State.HITSTUN,
    FighterStateMachine.State.KNOCKDOWN,
    FighterStateMachine.State.GETUP,
    FighterStateMachine.State.KO,
]

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    for index in range(RosterRegistry.count()):
        var p1 := RosterRegistry.entry(index)
        var p2 := RosterRegistry.entry((index + 1) % RosterRegistry.count())
        var scene := await _open_match(p1["id"] as StringName, p2["id"] as StringName)
        var label := "%s vs %s" % [String(p1["id"]), String(p2["id"])]
        _check(scene != null, "%s opens through ModeSelect into a real BattleScene" % label)
        if scene != null:
            _check(scene.simulation != null and scene.presentation_controller.configured,
                "%s configures simulation and presentation together" % label)
            _check(scene.presentation_controller.p1_controller != null and scene.presentation_controller.p2_controller != null,
                "%s creates both inventory-backed fighter visuals" % label)
            if scene.simulation != null:
                for state_value in STATE_SAMPLES:
                    scene.simulation.fighter_a.state_machine.state = state_value
                    scene.presentation_controller.sync_from_simulation()
                    _check(scene.presentation_controller.p1_controller.current_animation_key != &"",
                        "%s %s resolves a visible P1 animation" % [label, FighterStateMachine.State.keys()[state_value]])
            await _close_scene(scene)
    print("\nBeta Phase 1 real BattleScene 14-character presentation QA: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)

func _open_match(p1_id: StringName, p2_id: StringName) -> BattleScene:
    var select := MODE_SELECT_SCENE.instantiate() as ModeSelectScene
    if select == null:
        return null
    root.add_child(select)
    current_scene = select
    await process_frame
    var p1_index := select.model.index_for_id(p1_id)
    var p2_index := select.model.index_for_id(p2_id)
    if p1_index < 0 or p2_index < 0:
        return null
    select.p1_select.select(p1_index)
    select.p2_select.select(p2_index)
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
