# Responsibility: Complete gameplay snapshot/restore/re-simulation foundation tests.
# Owns tests only; no networking/rollback transport or presentation prediction is implemented.
class_name SnapshotRestoreTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_120_to_180_roundtrip_signature()
    _test_mid_move_and_reaction_restore_cases()
    _test_duplicate_hit_registry_restore()
    _test_input_history_dash_restore()
    _test_buffered_action_intent_restore()
    print("\nSnapshot/Restore tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 40000, p2_x: int = 100000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(character, character, null, null, Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS), Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _input_pattern(frame: int, sign: int) -> InputFrame:
    var phase := frame % 40
    if phase == 1:
        return InputFrame.new(frame, 0, 1, 0, 0, 0)
    if phase == 2:
        return InputFrame.with_light_press(frame)
    if phase == 18:
        return InputFrame.new(frame, sign, 0, 0, 0, 0)
    if phase == 19:
        return InputFrame.neutral(frame)
    if phase == 20:
        return InputFrame.new(frame, sign, 0, 0, 0, 0)
    if phase == 30:
        return InputFrame.with_heavy_press(frame, sign)
    return InputFrame.neutral(frame)

func _test_120_to_180_roundtrip_signature() -> void:
    var battle := _battle(26000, 102000)
    for f in range(1, 121):
        battle.simulate_frame(_input_pattern(f, 1), _input_pattern(f, -1))
    var snapshot := battle.capture_state()
    t.equal(snapshot.frame_number, 120, "Snapshot captures battle frame number at F120")
    t.that(snapshot.fighter_a.input_history_count > 0 and snapshot.fighter_a.input_history_slots.size() == 60, "Snapshot captures complete 60-slot InputHistory circular state")

    var replay_a: Array[InputFrame] = []
    var replay_b: Array[InputFrame] = []
    for f in range(121, 181):
        replay_a.append(_input_pattern(f, 1))
        replay_b.append(_input_pattern(f, -1))
        battle.simulate_frame(replay_a[-1], replay_b[-1])
    var signature_a := battle.state_signature()

    t.that(battle.restore_state(snapshot), "restore_state accepts complete F120 gameplay snapshot")
    t.equal(battle.frame_number, 120, "restore_state restores exact source frame")
    for i in range(replay_a.size()):
        battle.simulate_frame(replay_a[i], replay_b[i])
    var signature_b := battle.state_signature()
    t.equal(signature_b, signature_a, "Capture -> simulate -> restore -> re-simulate yields identical final state signature")

func _test_mid_move_and_reaction_restore_cases() -> void:
    var light_active := _battle()
    _tick(light_active, InputFrame.with_light_press(1))
    for _i in range(4):
        _tick(light_active)
    t.equal(light_active.fighter_a.move_runner.phase(), &"ACTIVE", "Setup reaches Light Active frame")
    _assert_restore_next(light_active, "Light Active frame")

    var heavy_recovery := _battle()
    _tick(heavy_recovery, InputFrame.with_heavy_press(1))
    for _i in range(15):
        _tick(heavy_recovery)
    t.equal(heavy_recovery.fighter_a.move_runner.phase(), &"RECOVERY", "Setup reaches Heavy Recovery")
    _assert_restore_next(heavy_recovery, "Heavy Recovery")

    var airborne := _battle()
    _tick(airborne, InputFrame.new(1, 0, 1, 0, 0, 0))
    t.equal(airborne.fighter_a.state_machine.state, FighterStateMachine.State.JUMP, "Setup reaches Airborne Jump")
    _assert_restore_next(airborne, "Airborne Jump")

    var air_attack := _battle()
    _tick(air_attack, InputFrame.new(1, 0, 1, 0, 0, 0))
    _tick(air_attack, InputFrame.with_light_press(2))
    t.equal(air_attack.fighter_a.state_machine.state, FighterStateMachine.State.AIR_ATTACK, "Setup reaches Air Attack")
    _assert_restore_next(air_attack, "Air Attack")

    var blockstun := _battle(50000, 58000)
    var guard_bit := InputFrame.InputButton.GUARD
    _tick(blockstun, InputFrame.with_light_press(1), InputFrame.new(1, 0, 0, guard_bit, guard_bit, 0))
    for _i in range(5):
        var f := blockstun.frame_number + 1
        _tick(blockstun, InputFrame.neutral(f), InputFrame.new(f, 0, 0, guard_bit, 0, 0))
    t.equal(blockstun.fighter_b.state_machine.state, FighterStateMachine.State.BLOCKSTUN, "Setup reaches Blockstun")
    _assert_restore_next(blockstun, "Blockstun", null, InputFrame.new(blockstun.frame_number + 1, 0, 0, guard_bit, 0, 0))

    var dash := _battle()
    _tick(dash, InputFrame.new(1, 1, 0, 0, 0, 0))
    _tick(dash, InputFrame.neutral(2))
    _tick(dash, InputFrame.new(3, 1, 0, 0, 0, 0))
    t.equal(dash.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "Setup reaches Dash")
    _assert_restore_next(dash, "Dash")

    var throw_active := _battle(30000, 100000)
    _tick(throw_active, InputFrame.with_heavy_press(1, 1))
    for _i in range(4):
        _tick(throw_active)
    t.equal(throw_active.fighter_a.move_runner.phase(), &"ACTIVE", "Setup reaches Throw Active")
    t.equal(throw_active.fighter_a.state_machine.state, FighterStateMachine.State.THROW, "Throw Active uses THROW state")
    _assert_restore_next(throw_active, "Throw Active")

    var thrown := _make_thrown_battle()
    t.equal(thrown.fighter_b.state_machine.state, FighterStateMachine.State.THROWN, "Setup reaches THROWN")
    _assert_restore_next(thrown, "Thrown")

    var knockdown := _make_thrown_battle()
    while knockdown.fighter_b.state_machine.state == FighterStateMachine.State.THROWN:
        _tick(knockdown)
    t.equal(knockdown.fighter_b.state_machine.state, FighterStateMachine.State.KNOCKDOWN, "Setup reaches Knockdown")
    _assert_restore_next(knockdown, "Knockdown")

    var getup := _make_thrown_battle()
    while getup.fighter_b.state_machine.state != FighterStateMachine.State.GETUP:
        _tick(getup)
    t.equal(getup.fighter_b.state_machine.state, FighterStateMachine.State.GETUP, "Setup reaches GetUp")
    _assert_restore_next(getup, "GetUp")

func _test_duplicate_hit_registry_restore() -> void:
    var battle := _battle(50000, 54000)
    _tick(battle, InputFrame.with_light_press(1))
    for _i in range(5):
        _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, 4950, "Setup strike has already damaged defender once")
    battle.fighter_a.combatant.hitstop_remaining = 0
    battle.fighter_b.combatant.hitstop_remaining = 0
    var snapshot := battle.capture_state()
    t.that(snapshot.fighter_a.contacted_defender_ids.has(2), "Snapshot captures AttackInstance contacted-defender registry")
    var hp_before := battle.fighter_b.combatant.hp
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, hp_before, "Already-contacted active frame does not hit twice before restore")
    t.that(battle.restore_state(snapshot), "Duplicate-hit snapshot restores")
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, hp_before, "Duplicate hit remains protected after restore")

func _test_input_history_dash_restore() -> void:
    var battle := _battle()
    _tick(battle, InputFrame.new(1, 1, 0, 0, 0, 0))
    var first_tap_snapshot := battle.capture_state()
    _tick(battle, InputFrame.neutral(2))
    _tick(battle, InputFrame.new(3, 1, 0, 0, 0, 0))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "Forward first tap + Neutral + second tap produces Dash")
    t.that(battle.restore_state(first_tap_snapshot), "Snapshot after first directional tap restores")
    _tick(battle, InputFrame.neutral(2))
    _tick(battle, InputFrame.new(3, 1, 0, 0, 0, 0))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "Restored InputHistory preserves first tap so replay still Dashes")

func _test_buffered_action_intent_restore() -> void:
    var battle := _battle()
    _tick(battle, InputFrame.with_light_press(1))
    while battle.fighter_a.move_runner.is_running() and battle.fighter_a.move_runner.move_frame < 16:
        _tick(battle)
    var request_frame := battle.frame_number + 1
    _tick(battle, InputFrame.with_light_press(request_frame, 0, -1))
    var before := battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(before != null and before.direction_y == -1, "Setup has buffered Down+Light ActionIntent")
    var snapshot := battle.capture_state()
    _tick(battle)
    t.that(battle.restore_state(snapshot), "Buffered ActionIntent snapshot restores")
    var restored := battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(restored != null, "InputBuffer pending intent exists after restore")
    t.equal(restored.action_button, before.action_button, "Buffered ActionIntent action_button restores")
    t.equal(restored.source_frame, before.source_frame, "Buffered ActionIntent source_frame restores")
    t.equal(restored.direction_y, before.direction_y, "Buffered ActionIntent direction context restores")
    t.equal(restored.facing_at_request, before.facing_at_request, "Buffered ActionIntent facing_at_request restores")
    t.equal(restored.forward_held, before.forward_held, "Buffered ActionIntent forward_held restores")
    t.equal(restored.back_held, before.back_held, "Buffered ActionIntent back_held restores")

func _make_thrown_battle() -> BattleSimulation:
    var battle := _battle(50000, 54000)
    var guard_bit := InputFrame.InputButton.GUARD
    _tick(battle, InputFrame.with_heavy_press(1, 1), InputFrame.new(1, 0, 0, guard_bit, guard_bit, 0))
    for _i in range(5):
        var f := battle.frame_number + 1
        _tick(battle, InputFrame.neutral(f), InputFrame.new(f, 0, 0, guard_bit, 0, 0))
    for _i in range(6):
        _tick(battle, null, InputFrame.new(battle.frame_number + 1, 0, 0, guard_bit, 0, 0))
    return battle

func _assert_restore_next(battle: BattleSimulation, label: String, next_a: InputFrame = null, next_b: InputFrame = null) -> void:
    var snapshot := battle.capture_state()
    var before_signature := battle.state_signature()
    var frame := battle.frame_number + 1
    var a := next_a if next_a != null else InputFrame.neutral(frame)
    var b := next_b if next_b != null else InputFrame.neutral(frame)
    battle.simulate_frame(a, b)
    var result_signature_a := battle.state_signature()
    t.that(battle.restore_state(snapshot), "%s snapshot restores successfully" % label)
    t.equal(battle.state_signature(), before_signature, "%s restores same canonical state" % label)
    battle.simulate_frame(a, b)
    t.equal(battle.state_signature(), result_signature_a, "%s restore produces same next simulation result" % label)
