# Responsibility: M3 data-defined Cancel/Chain/Link, 5F buffer, meter gate, and AttackInstance replacement regression suite.
class_name Milestone3CancelTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_cancel_window_data_contract()
    _test_light_hit_cancel_routes()
    _test_light_block_cancel_routes()
    _test_light_whiff_cancel_denied()
    _test_heavy_hit_and_block_to_special()
    _test_heavy_whiff_and_early_buffer_expiry()
    _test_special_hit_to_ultimate_meter_gate()
    _test_special_block_and_whiff_ultimate_denial()
    _test_latest_intent_wins_complete_snapshot_context()
    _test_link_after_recovery_is_not_cancel()
    _test_cancel_replaces_attack_instance()
    print("\nM3 Cancel/Combo tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(close: bool = true) -> BattleSimulation:
    var battle := BattleSimulation.new()
    var p2_x := 58000 if close else 100000
    battle.configure(character, character, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _guard(frame: int, pressed: bool = false) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, 0, bit, bit if pressed else 0, 0)

func _action_frame(frame: int, button: int) -> InputFrame:
    return InputFrame.new(frame, 0, 0, button, button, 0)

func _setup_light_contact(blocked: bool) -> BattleSimulation:
    var battle := _battle(true)
    _tick(battle, InputFrame.with_light_press(1), _guard(1, true) if blocked else null)
    for _i in range(5):
        var f := battle.frame_number + 1
        _tick(battle, null, _guard(f) if blocked else null)
    t.that(battle.fighter_a.move_runner.connected_block if blocked else battle.fighter_a.move_runner.connected_hit, "Light setup records resolved connection fact")
    t.equal(battle.fighter_a.move_runner.move_frame, 6, "Light connection hitstop freezes timeline on cancel-window frame 6")
    return battle

func _finish_light_cancel(battle: BattleSimulation, target_button: int, blocked: bool) -> void:
    var f := battle.frame_number + 1
    _tick(battle, _action_frame(f, target_button), _guard(f) if blocked else null)
    for _i in range(3):
        f = battle.frame_number + 1
        _tick(battle, null, _guard(f) if blocked else null)

func _setup_heavy_contact(blocked: bool) -> BattleSimulation:
    var battle := _battle(true)
    _tick(battle, InputFrame.with_heavy_press(1), _guard(1, true) if blocked else null)
    for _i in range(11):
        var f := battle.frame_number + 1
        _tick(battle, null, _guard(f) if blocked else null)
    t.that(battle.fighter_a.move_runner.connected_block if blocked else battle.fighter_a.move_runner.connected_hit, "Heavy setup records resolved connection fact")
    t.equal(battle.fighter_a.move_runner.move_frame, 12, "Heavy connection hitstop freezes timeline on cancel-window frame 12")
    return battle

func _finish_heavy_special_cancel(battle: BattleSimulation, blocked: bool) -> void:
    var f := battle.frame_number + 1
    _tick(battle, InputFrame.with_special_press(f), _guard(f) if blocked else null)
    for _i in range(5):
        f = battle.frame_number + 1
        _tick(battle, null, _guard(f) if blocked else null)

func _setup_special_contact(blocked: bool, starting_meter: int) -> BattleSimulation:
    var battle := _battle(true)
    battle.fighter_a.meter.gain(starting_meter)
    _tick(battle, InputFrame.with_special_press(1), _guard(1, true) if blocked else null)
    for _i in range(11):
        var f := battle.frame_number + 1
        _tick(battle, null, _guard(f) if blocked else null)
    t.that(battle.fighter_a.move_runner.connected_block if blocked else battle.fighter_a.move_runner.connected_hit, "Special setup records resolved connection fact")
    t.equal(battle.fighter_a.move_runner.move_frame, 11, "Special connection hitstop freezes timeline on cancel-window frame 11")
    return battle

func _finish_special_ultimate_attempt(battle: BattleSimulation, blocked: bool) -> void:
    var f := battle.frame_number + 1
    _tick(battle, InputFrame.with_ultimate_press(f), _guard(f) if blocked else null)
    for _i in range(5):
        f = battle.frame_number + 1
        _tick(battle, null, _guard(f) if blocked else null)

func _test_cancel_window_data_contract() -> void:
    var registry := MoveRegistry.new()
    registry.configure(character.move_set)
    var light := registry.get_move(MoveIds.STAND_LIGHT)
    var heavy := registry.get_move(MoveIds.STAND_HEAVY)
    var special := registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    t.equal(light.cancel_windows.size(), 1, "Stand Light has one data-defined cancel window")
    t.equal(light.cancel_windows[0].start_frame, 6, "Light cancel starts F6")
    t.equal(light.cancel_windows[0].end_frame, 12, "Light cancel ends F12 inclusive")
    t.equal(light.cancel_windows[0].condition, CancelWindowData.Condition.ON_HIT_OR_BLOCK, "Light cancel requires HIT or BLOCK")
    t.that(light.cancel_windows[0].allowed_target_move_ids.has(MoveIds.STAND_LIGHT) and light.cancel_windows[0].allowed_target_move_ids.has(MoveIds.STAND_HEAVY), "Light cancel targets Light and Heavy only")
    t.equal(heavy.cancel_windows[0].start_frame, 12, "Heavy cancel starts F12")
    t.equal(heavy.cancel_windows[0].end_frame, 20, "Heavy cancel ends F20 inclusive")
    t.equal(heavy.cancel_windows[0].condition, CancelWindowData.Condition.ON_HIT_OR_BLOCK, "Heavy cancel requires HIT or BLOCK")
    t.equal(heavy.cancel_windows[0].allowed_target_move_ids[0], MoveIds.SPECIAL_NEUTRAL, "Heavy cancel target is Special")
    t.equal(special.cancel_windows[0].start_frame, 11, "Special cancel starts F11")
    t.equal(special.cancel_windows[0].end_frame, 18, "Special cancel ends F18 inclusive")
    t.equal(special.cancel_windows[0].condition, CancelWindowData.Condition.ON_HIT, "Special cancel requires HIT only")
    t.equal(special.cancel_windows[0].allowed_target_move_ids[0], MoveIds.ULTIMATE, "Special cancel target is Ultimate")

func _test_light_hit_cancel_routes() -> void:
    var to_light := _setup_light_contact(false)
    _finish_light_cancel(to_light, InputFrame.InputButton.LIGHT, false)
    t.equal(to_light.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Light HIT -> Light chain works")
    t.equal(to_light.fighter_a.move_runner.connection_name(), "NONE", "New chained Light resets connection facts")

    var to_heavy := _setup_light_contact(false)
    _finish_light_cancel(to_heavy, InputFrame.InputButton.HEAVY, false)
    t.equal(to_heavy.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Light HIT -> Heavy chain works")

func _test_light_block_cancel_routes() -> void:
    var to_light := _setup_light_contact(true)
    _finish_light_cancel(to_light, InputFrame.InputButton.LIGHT, true)
    t.equal(to_light.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Light BLOCK -> Light chain works")

    var to_heavy := _setup_light_contact(true)
    _finish_light_cancel(to_heavy, InputFrame.InputButton.HEAVY, true)
    t.equal(to_heavy.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Light BLOCK -> Heavy chain works")

func _test_light_whiff_cancel_denied() -> void:
    var battle := _battle(false)
    _tick(battle, InputFrame.with_light_press(1))
    for _i in range(5):
        _tick(battle)
    _tick(battle, InputFrame.with_heavy_press(7))
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Light WHIFF -> Heavy cancel is denied inside frame window")
    for _i in range(6):
        _tick(battle)
    t.that(battle.fighter_a.move_runner.current_move_id() != MoveIds.STAND_HEAVY, "Whiff-denied Heavy buffer expires instead of becoming a permanent queue")

func _test_heavy_hit_and_block_to_special() -> void:
    var hit := _setup_heavy_contact(false)
    _finish_heavy_special_cancel(hit, false)
    t.equal(hit.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL, "Heavy HIT -> Special cancel works")

    var block := _setup_heavy_contact(true)
    _finish_heavy_special_cancel(block, true)
    t.equal(block.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL, "Heavy BLOCK -> Special cancel works")

func _test_heavy_whiff_and_early_buffer_expiry() -> void:
    var whiff := _battle(false)
    _tick(whiff, InputFrame.with_heavy_press(1))
    for _i in range(11):
        _tick(whiff)
    _tick(whiff, InputFrame.with_special_press(13))
    t.equal(whiff.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Heavy WHIFF -> Special cancel denied")

    var early := _battle(false)
    _tick(early, InputFrame.with_heavy_press(1))
    _tick(early, InputFrame.with_special_press(2))
    for _i in range(11):
        _tick(early)
    t.equal(early.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Special pressed too early in Heavy startup expires before cancel window")
    t.that(not early.fighter_a.input_buffer.has_pending(early.frame_number), "Early Special buffer is expired/cleared by the time Heavy cancel window arrives")

func _test_special_hit_to_ultimate_meter_gate() -> void:
    var success := _setup_special_contact(false, 82)
    t.equal(success.fighter_a.meter.get_value(), 100, "Special HIT raises 82 meter to 100 before later cancel decision")
    _finish_special_ultimate_attempt(success, false)
    t.equal(success.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "Special HIT -> Ultimate works at 100 meter")
    t.equal(success.fighter_a.meter.get_value(), 0, "Special -> Ultimate cancel spends 100 immediately")

    var denied := _setup_special_contact(false, 81)
    t.equal(denied.fighter_a.meter.get_value(), 99, "Special HIT raises 81 meter to exactly 99")
    _finish_special_ultimate_attempt(denied, false)
    t.that(denied.fighter_a.move_runner.current_move_id() != MoveIds.ULTIMATE, "Special HIT -> Ultimate denied at 99 meter")
    t.equal(denied.fighter_a.meter.get_value(), 99, "Meter-denied cancel does not spend or refund")

func _test_special_block_and_whiff_ultimate_denial() -> void:
    var blocked := _setup_special_contact(true, 100)
    _finish_special_ultimate_attempt(blocked, true)
    t.that(blocked.fighter_a.move_runner.current_move_id() != MoveIds.ULTIMATE, "Special BLOCK cannot cancel into Ultimate")
    t.equal(blocked.fighter_a.meter.get_value(), 100, "Blocked Special Ultimate denial does not spend meter")

    var whiff := _battle(false)
    whiff.fighter_a.meter.gain(100)
    _tick(whiff, InputFrame.with_special_press(1))
    for _i in range(10):
        _tick(whiff)
    _tick(whiff, InputFrame.with_ultimate_press(12))
    t.that(whiff.fighter_a.move_runner.current_move_id() != MoveIds.ULTIMATE, "Special WHIFF cannot cancel into Ultimate")
    t.equal(whiff.fighter_a.meter.get_value(), 100, "Whiff-denied Ultimate does not spend meter")

func _test_latest_intent_wins_complete_snapshot_context() -> void:
    var buffer := InputBuffer.new()
    var light := ActionIntent.new(InputFrame.InputButton.LIGHT, 100, -1, -1, -1)
    var special := ActionIntent.new(InputFrame.InputButton.SPECIAL, 101, 1, 0, -1)
    t.that(buffer.buffer_intent(light), "Buffer accepts Light intent")
    t.that(buffer.buffer_intent(special), "Buffer accepts later Special intent")
    var stored := buffer.peek_intent(101)
    t.equal(stored.action_button, InputFrame.InputButton.SPECIAL, "LATEST INTENT WINS replaces action with Special")
    t.equal(stored.source_frame, 101, "Latest intent source_frame replaces old source frame")
    t.equal(stored.direction_x, 1, "Latest intent direction_x replaces old context")
    t.equal(stored.direction_y, 0, "Latest intent direction_y replaces old context")
    t.equal(stored.facing_at_request, -1, "Latest intent facing_at_request remains request-frame snapshot")
    t.equal(stored.forward_held, false, "Latest Special request stores its own forward context")
    t.equal(stored.back_held, true, "Latest Special request stores its own back context")

func _test_link_after_recovery_is_not_cancel() -> void:
    var battle := _battle(false)
    _tick(battle, InputFrame.with_light_press(1))
    var guard := 0
    while battle.fighter_a.move_runner.is_running() and guard < 40:
        _tick(battle)
        guard += 1
    t.that(not battle.fighter_a.move_runner.is_running(), "Whiffed Light fully recovers before Link test")
    var old_serial := battle.fighter_a.move_runner.instance_serial()
    var f := battle.frame_number + 1
    _tick(battle, InputFrame.with_heavy_press(f))
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Heavy starts normally after recovery as a Link/actionable start")
    t.equal(battle.fighter_a.move_runner.instance_serial(), old_serial + 1, "Link uses normal new AttackInstance start path")

func _test_cancel_replaces_attack_instance() -> void:
    var battle := _setup_light_contact(false)
    var light_instance := battle.fighter_a.move_runner.attack_instance_id
    var light_serial := battle.fighter_a.move_runner.instance_serial()
    _finish_light_cancel(battle, InputFrame.InputButton.HEAVY, false)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Cancel replacement target is Heavy")
    t.that(battle.fighter_a.move_runner.attack_instance_id != light_instance, "Cancel creates a new AttackInstanceID")
    t.equal(battle.fighter_a.move_runner.instance_serial(), light_serial + 1, "Cancel increments deterministic per-fighter AttackInstance serial")
    t.equal(battle.fighter_a.hitbox_owner.tracked_attack_instance_id(), battle.fighter_a.move_runner.attack_instance_id, "Cancel resets duplicate-contact registry identity to new attack instance")
