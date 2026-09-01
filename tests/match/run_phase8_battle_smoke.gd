# Phase 8 real frontend -> BattleScene -> BattleSimulation representative match smoke.
# Test fixtures may place fighters at contact range or set meter/HP, but every
# observed action, hit, block, KO and round transition is produced by real
# normalized InputFrames through the configured BattleScene simulation.
extends SceneTree

const MODE_SELECT_SCENE := preload("res://frontend/mode_select_scene.tscn")
const SPECIAL := InputFrame.InputButton.SPECIAL
const GUARD := InputFrame.InputButton.GUARD

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    await _run_doge_vs_alien()
    await _run_pink_vs_bao()
    await _run_penguin_vs_magic()
    print("\nPhase 8 representative BattleScene smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)

func _run_doge_vs_alien() -> void:
    var scene := await _open_match(&"doge", &"alien_meow")
    _check(scene != null, "Doge vs Alien opens through ModeSelect into BattleScene")
    if scene == null:
        return
    var battle := scene.simulation
    _verify_scene_identity_and_spawns(scene, &"doge", &"alien_meow", "Doge vs Alien")
    _exercise_common_actions(battle, "Doge vs Alien")
    _exercise_special_levels(battle, 1, "Doge")
    _exercise_special_levels(battle, 2, "Alien Meow")

    _reset_to_contact(battle)
    _charge_release(battle, 1, 54)
    var armor_seen := false
    for _i in range(12):
        _tick(battle)
        armor_seen = armor_seen or battle.fighter_a.mechanics_runtime.armor_remaining_hits == 1
    _check(armor_seen, "Doge Lv3 enters its authored one-hit strike armor window")

    _reset_to_contact(battle)
    _tick(battle, _special_input(battle, true, true), InputFrame.with_light_press(battle.frame_number + 1))
    for _i in range(8):
        _tick(battle, _special_input(battle, true))
    _check(battle.fighter_a.state_machine.state != FighterStateMachine.State.CHARGE, "Doge charge is interrupted by a real Alien Light")

    _reset_to_contact(battle)
    _charge_release(battle, 2, 54)
    for _i in range(16): _tick(battle)
    _check(battle.fighter_a.has_status(&"signal_mark"), "Alien Lv3 Scan applies Signal Mark through real release and hit")
    _wait_for_idle(battle)
    battle.fighter_b.meter.set_value(100)
    _tick(battle, null, InputFrame.with_ultimate_press(battle.frame_number + 1))
    _tick(battle)
    var sequence := _first_entity_of_kind(battle, TemporaryEntityRuntime.Kind.SEQUENCE)
    _check(sequence != null, "Alien Ultimate spawns Position Lock through BattleScene simulation")
    if sequence != null:
        var recorded: Vector2i = sequence.recorded_positions.get(0, Vector2i.ZERO)
        for _i in range(6): _tick(battle, InputFrame.new(battle.frame_number + 1, -1))
        _check(sequence.recorded_positions.get(0, Vector2i.ZERO) == recorded, "Alien Position Lock remains non-homing after the target moves")
    _verify_real_ko_and_round_reset(battle, "Doge vs Alien")
    await _close_scene(scene)

func _run_pink_vs_bao() -> void:
    var scene := await _open_match(&"pink_star", &"bao_la")
    _check(scene != null, "Pink vs Bao opens through ModeSelect into BattleScene")
    if scene == null:
        return
    var battle := scene.simulation
    _verify_scene_identity_and_spawns(scene, &"pink_star", &"bao_la", "Pink vs Bao")
    _exercise_common_actions(battle, "Pink vs Bao")
    _exercise_special_levels(battle, 1, "Pink Star")
    _exercise_special_levels(battle, 2, "Bao La")

    _reset_to_contact(battle)
    battle.fighter_a.meter.set_value(100)
    _tick(battle, InputFrame.with_ultimate_press(battle.frame_number + 1))
    _check(battle.fighter_a.get_active_mode_id() == &"true_face" and battle.fighter_a.get_resource_value(&"face_actions") == 5, "Pink Ultimate enters True Face with five Stars")
    _wait_for_idle(battle)
    _tick(battle, InputFrame.with_ultimate_press(battle.frame_number + 1))
    _check(battle.fighter_a.move_runner.current_move_id().begins_with("pink_true_finisher_") and battle.fighter_a.get_resource_value(&"face_actions") == 0, "Pink Ultimate in True Face starts and pays the Finisher")

    _reset_to_contact(battle)
    # Start Pink Heavy early enough that its real active frame overlaps Bao's
    # authored Lv3 counter release window.
    for held_frame in range(1, 55):
        var a := InputFrame.with_heavy_press(battle.frame_number + 1) if held_frame == 50 else InputFrame.neutral(battle.frame_number + 1)
        var b := _special_input(battle, true, held_frame == 1)
        _tick(battle, a, b)
    _tick(battle, null, _special_input(battle, false, false, true))
    for _i in range(12): _tick(battle)
    _check(battle.fighter_b.move_runner.current_move_id() == &"bao_counter_success_l3", "Bao Lv3 Counter releases through real charge input and routes to its success move")

    # The Lv3 counter exchange can leave the opposing fighter in a legal but
    # non-idle recovery state. Start this independent Last Stand contract from
    # the real match-reset path so input timing is not coupled to that smoke.
    _wait_for_idle(battle)
    _reset_to_contact(battle)
    battle.fighter_b.meter.set_value(100)
    _tick(battle, null, InputFrame.with_ultimate_press(battle.frame_number + 1))
    _check(battle.fighter_b.get_active_mode_id() == &"last_stand", "Bao Ultimate enters Last Stand through real input")
    for _i in range(24): _tick(battle)
    _place_at_contact(battle)
    _tick(battle, InputFrame.with_light_press(battle.frame_number + 1))
    for _i in range(8): _tick(battle)
    _check(battle.fighter_b.get_resource_value(&"resolve") >= 1, "Bao Last Stand receives a real hit and gains Resolve")
    for _i in range(24): _tick(battle)
    _place_at_contact(battle)
    _throw(battle, false)
    _check(battle.fighter_b.combatant.last_result_type == HitResult.ResultType.THROW and battle.fighter_b.get_resource_value(&"resolve") == 0, "Normal Throw hard-counters Bao Last Stand Resolve")
    _verify_real_ko_and_round_reset(battle, "Pink vs Bao")
    await _close_scene(scene)

func _run_penguin_vs_magic() -> void:
    var scene := await _open_match(&"tempura_penguin", &"magic_orange_cat")
    _check(scene != null, "Penguin vs Magic opens through ModeSelect into BattleScene")
    if scene == null:
        return
    var battle := scene.simulation
    _verify_scene_identity_and_spawns(scene, &"tempura_penguin", &"magic_orange_cat", "Penguin vs Magic")
    _exercise_common_actions(battle, "Penguin vs Magic")
    _exercise_special_levels(battle, 1, "Tempura Penguin")
    _exercise_special_levels(battle, 2, "Magic Orange Cat")

    _reset_to_contact(battle)
    battle.fighter_a.meter.set_value(100)
    _tick(battle, InputFrame.with_ultimate_press(battle.frame_number + 1))
    var summon_count := 0
    var max_attack_capable := 0
    for _i in range(110):
        _tick(battle)
        summon_count = maxi(summon_count, _entity_count(battle, TemporaryEntityRuntime.Kind.SUMMON))
        max_attack_capable = maxi(max_attack_capable, _attack_capable_summon_count(battle))
    _check(summon_count == 9 and max_attack_capable <= 3, "Penguin Ultimate schedules 3x3 summons with at most three attack threats")

    _reset_to_contact(battle)
    _charge_release(battle, 2, 3)
    _check(_entity_count(battle, TemporaryEntityRuntime.Kind.AREA) == 1, "Magic Lv1 Special creates one standard trap through real input")
    _wait_for_idle(battle)
    _charge_release(battle, 2, 3)
    _check(_entity_count(battle, TemporaryEntityRuntime.Kind.AREA) == 1, "Magic trap replacement keeps the authoritative standard-trap cap at one")

    _wait_for_idle(battle)
    battle.fighter_b.meter.set_value(100)
    _tick(battle, null, InputFrame.with_ultimate_press(battle.frame_number + 1))
    var zones := _first_entity_of_kind(battle, TemporaryEntityRuntime.Kind.SEQUENCE)
    _check(zones != null, "Magic Ultimate creates its warned four-zone sequence through real input")
    if zones != null:
        for _i in range(96): _tick(battle)
        _check(zones.sequence_step_mask == 15, "Magic Ultimate activates all four warned zones deterministically")
    _verify_real_ko_and_round_reset(battle, "Penguin vs Magic")
    await _close_scene(scene)

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
        _check(false, "ModeSelect resolves %s and %s" % [String(p1_id), String(p2_id)])
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

func _verify_scene_identity_and_spawns(scene: BattleScene, p1_id: StringName, p2_id: StringName, label: String) -> void:
    var battle := scene.simulation
    _check(battle != null and battle.fighter_a.data == RosterRegistry.character_by_id(p1_id) and battle.fighter_b.data == RosterRegistry.character_by_id(p2_id), "%s preserves frontend CharacterData identity" % label)
    if battle == null:
        return
    _check(battle.fighter_a.movement_motor.sim_position == battle.configured_start_position(1) and battle.fighter_b.movement_motor.sim_position == battle.configured_start_position(2), "%s starts at BattleSimulation-owned canonical spawns" % label)

func _exercise_common_actions(battle: BattleSimulation, label: String) -> void:
    battle.reset_full_match()
    var start_x := battle.fighter_a.movement_motor.sim_position.x
    _tick(battle, InputFrame.new(battle.frame_number + 1, 1))
    _check(battle.fighter_a.movement_motor.sim_position.x > start_x, "%s real walk advances P1" % label)
    battle.reset_full_match()
    _tick(battle, InputFrame.new(battle.frame_number + 1, 1)); _tick(battle); _tick(battle, InputFrame.new(battle.frame_number + 1, 1))
    _check(battle.fighter_a.state_machine.state == FighterStateMachine.State.DASH_FORWARD, "%s real forward-neutral-forward starts Dash" % label)
    battle.reset_full_match()
    _tick(battle, InputFrame.new(battle.frame_number + 1, -1)); _tick(battle); _tick(battle, InputFrame.new(battle.frame_number + 1, -1))
    _check(battle.fighter_a.state_machine.state == FighterStateMachine.State.BACKSTEP, "%s real back-neutral-back starts Backstep" % label)
    battle.reset_full_match()
    _tick(battle, InputFrame.new(battle.frame_number + 1, 0, 1))
    _check(battle.fighter_a.is_airborne(), "%s real Up input starts Jump" % label)

    _reset_to_contact(battle)
    _tick(battle, InputFrame.with_light_press(battle.frame_number + 1), _guard_input(battle))
    for _i in range(8): _tick(battle, null, _guard_input(battle))
    _check(battle.fighter_b.combatant.last_result_type == HitResult.ResultType.BLOCK, "%s real Guard blocks Light" % label)
    _wait_for_idle(battle)
    _tick(battle, InputFrame.with_heavy_press(battle.frame_number + 1))
    for _i in range(14): _tick(battle)
    _check(battle.fighter_b.combatant.last_result_type == HitResult.ResultType.HIT, "%s real Heavy produces a hit reaction" % label)
    _wait_for_idle(battle)
    _tick(battle, InputFrame.with_light_press(battle.frame_number + 1, 0, -1))
    _check(battle.fighter_a.move_runner.current_move_id() == MoveIds.CROUCH_LOW, "%s real Down+Light starts Low" % label)
    _wait_for_idle(battle)
    _reset_to_contact(battle)
    _throw(battle, false)
    _check(battle.fighter_b.combatant.last_result_type == HitResult.ResultType.THROW, "%s real Forward+Heavy starts Normal Throw" % label)
    _reset_to_contact(battle)
    _throw(battle, true)
    _check(battle.fighter_b.combatant.last_result_type != HitResult.ResultType.THROW, "%s simultaneous Normal Throws tech" % label)

func _exercise_special_levels(battle: BattleSimulation, fighter_id: int, character_label: String) -> void:
    var held_frames := [3, 24, 54]
    for index in range(held_frames.size()):
        _reset_to_contact(battle)
        _charge_release(battle, fighter_id, held_frames[index])
        var fighter := battle.fighter_a if fighter_id == 1 else battle.fighter_b
        var expected_suffix := "_l%d" % (index + 1)
        _check(fighter.move_runner.current_move_id().ends_with(expected_suffix), "%s Special Lv%d releases its authored move through real input" % [character_label, index + 1])

func _reset_to_contact(battle: BattleSimulation) -> void:
    battle.reset_full_match()
    _place_at_contact(battle)
    battle.drain_events()

func _place_at_contact(battle: BattleSimulation) -> void:
    battle.fighter_a.movement_motor.sim_position = Vector2i(50000, BattleSimulation.GROUND_Y_UNITS)
    battle.fighter_b.movement_motor.sim_position = Vector2i(55000, BattleSimulation.GROUND_Y_UNITS)
    battle.fighter_a.movement_motor.facing = 1
    battle.fighter_b.movement_motor.facing = -1

func _throw(battle: BattleSimulation, tech: bool) -> void:
    _tick(battle, InputFrame.with_heavy_press(battle.frame_number + 1, 1), InputFrame.with_heavy_press(battle.frame_number + 1, -1) if tech else _guard_input(battle))
    for _i in range(12): _tick(battle, null, InputFrame.neutral(battle.frame_number + 1) if tech else _guard_input(battle))

func _charge_release(battle: BattleSimulation, fighter_id: int, held_frames: int) -> void:
    for held_frame in range(1, held_frames + 1):
        var special := _special_input(battle, true, held_frame == 1)
        _tick(battle, special if fighter_id == 1 else null, special if fighter_id == 2 else null)
    var release := _special_input(battle, false, false, true)
    _tick(battle, release if fighter_id == 1 else null, release if fighter_id == 2 else null)

func _special_input(battle: BattleSimulation, held: bool, pressed: bool = false, released: bool = false) -> InputFrame:
    return InputFrame.new(battle.frame_number + 1, 0, 0, SPECIAL if held else 0, SPECIAL if pressed else 0, SPECIAL if released else 0)

func _guard_input(battle: BattleSimulation) -> InputFrame:
    return InputFrame.new(battle.frame_number + 1, 0, 0, GUARD, GUARD, 0)

func _tick(battle: BattleSimulation, p1: InputFrame = null, p2: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(p1 if p1 != null else InputFrame.neutral(frame), p2 if p2 != null else InputFrame.neutral(frame))

func _wait_for_idle(battle: BattleSimulation, frames: int = 100) -> void:
    for _i in range(frames):
        _tick(battle)
        if not battle.fighter_a.move_runner.is_running() and not battle.fighter_b.move_runner.is_running() and battle.fighter_a.state_machine.state == FighterStateMachine.State.IDLE and battle.fighter_b.state_machine.state == FighterStateMachine.State.IDLE:
            return

func _verify_real_ko_and_round_reset(battle: BattleSimulation, label: String) -> void:
    _reset_to_contact(battle)
    battle.fighter_b.combatant.hp = 1
    _tick(battle, InputFrame.with_light_press(battle.frame_number + 1))
    for _i in range(8): _tick(battle)
    _check(battle.fighter_b.combatant.is_ko and battle.round_controller.state == RoundController.State.POST_ROUND, "%s real Light damage causes KO and round end" % label)
    for _i in range(battle.round_controller.rules.post_round_frames): _tick(battle)
    _check(battle.round_controller.state == RoundController.State.ROUND_ACTIVE and battle.fighter_a.movement_motor.sim_position == battle.configured_start_position(1) and battle.fighter_b.movement_motor.sim_position == battle.configured_start_position(2), "%s next round resets canonical starts through BattleSimulation" % label)

func _entity_count(battle: BattleSimulation, kind: int) -> int:
    var count := 0
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == kind:
            count += 1
    return count

func _first_entity_of_kind(battle: BattleSimulation, kind: int) -> TemporaryEntityRuntime:
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == kind:
            return runtime
    return null

func _attack_capable_summon_count(battle: BattleSimulation) -> int:
    var count := 0
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == TemporaryEntityRuntime.Kind.SUMMON and (runtime.phase == 1 or runtime.phase == 2):
            count += 1
    return count

func _check(condition: bool, label: String) -> void:
    if condition:
        print("[PASS] %s" % label)
        return
    failures += 1
    push_error("[FAIL] %s" % label)
