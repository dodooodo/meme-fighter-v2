# Responsibility: M2.4 Ground Throw + Dash/Backstep regression suite.
# Owns tests only; production recognition/collision/state mutation remain separate.
class_name Milestone24ThrowMobilityTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_throw_mapping_and_data()
    _test_throw_success_whiff_and_eligibility()
    _test_throw_duplicate_contact()
    _test_dash_recognition_windows()
    _test_dash_relative_facing_and_exact_movement()
    _test_dash_stage_hit_ko_rules()
    print("\nM2.4 Throw + Mobility tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 50000, p2_x: int = 58000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(character, character, null, null, Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS), Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _dir(frame: int, x: int = 0, y: int = 0) -> InputFrame:
    return InputFrame.new(frame, x, y, 0, 0, 0)

func _heavy(frame: int, x: int = 0, y: int = 0) -> InputFrame:
    return InputFrame.with_heavy_press(frame, x, y)

func _guard(frame: int, down: bool = false) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, -1 if down else 0, bit, bit, 0)

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _test_throw_mapping_and_data() -> void:
    var forward_heavy := ActionIntent.new(InputFrame.InputButton.HEAVY, 1, 1, 0, 1)
    var neutral_heavy := ActionIntent.new(InputFrame.InputButton.HEAVY, 1, 0, 0, 1)
    var back_heavy := ActionIntent.new(InputFrame.InputButton.HEAVY, 1, -1, 0, 1)
    var down_heavy := ActionIntent.new(InputFrame.InputButton.HEAVY, 1, 0, -1, 1)
    t.equal(ActionMoveMap.ground_move_id_for_intent(forward_heavy), MoveIds.GROUND_THROW, "Forward+Heavy maps Throw using request-frame forward_held")
    t.equal(ActionMoveMap.ground_move_id_for_intent(neutral_heavy), MoveIds.STAND_HEAVY, "Neutral+Heavy remains Stand Heavy")
    t.equal(ActionMoveMap.ground_move_id_for_intent(back_heavy), MoveIds.STAND_HEAVY, "Back+Heavy remains Stand Heavy")
    t.equal(ActionMoveMap.ground_move_id_for_intent(down_heavy), MoveIds.STAND_HEAVY, "Down+Heavy remains Stand Heavy")
    t.equal(ActionMoveMap.air_move_id_for_intent(forward_heavy), MoveIds.AIR_ATTACK, "Air Forward+Heavy maps Air Attack, not Throw")

    var registry := MoveRegistry.new()
    registry.configure(character.move_set)
    var throw_move := registry.get_move(MoveIds.GROUND_THROW)
    t.equal(throw_move.startup_frames, 5, "Ground Throw startup 5F")
    t.equal(throw_move.active_frames, 2, "Ground Throw active 2F")
    t.equal(throw_move.recovery_frames, 18, "Ground Throw recovery 18F")
    t.equal(throw_move.damage, 120, "Ground Throw damage = 120")
    t.equal(throw_move.throw_hold_frames, 10, "Ground Throw hold = 10F")
    t.equal(throw_move.knockdown_frames, 30, "Ground Throw knockdown = 30F")
    t.that(throw_move.hitbox == null and throw_move.throw_box != null, "Throw uses separate throw_box and no Strike hitbox")

func _test_throw_success_whiff_and_eligibility() -> void:
    var success := _battle()
    _tick(success, _heavy(1, 1), _guard(1))
    for _i in range(5):
        var f := success.frame_number + 1
        _tick(success, InputFrame.neutral(f), _guard(f))
    t.equal(success.fighter_b.combatant.hp, 4880, "Throw succeeds against Guard for 120 damage")
    t.equal(success.fighter_b.state_machine.state, FighterStateMachine.State.THROWN, "Successful Throw enters THROWN")

    var whiff := _battle(30000, 100000)
    _tick(whiff, _heavy(1, 1))
    for _i in range(5):
        _tick(whiff)
    t.equal(whiff.fighter_b.combatant.hp, 5000, "Throw fails outside range")
    t.equal(whiff.fighter_a.move_runner.current_move_id(), MoveIds.GROUND_THROW, "Throw whiffs instead of becoming Heavy")
    t.equal(whiff.fighter_a.state_machine.state, FighterStateMachine.State.THROW, "Throw whiff remains THROW until MoveData recovery completes")

    var airborne := _battle()
    _tick(airborne, _heavy(1, 1), _dir(1, 0, 1))
    for _i in range(5):
        _tick(airborne)
    t.equal(airborne.fighter_b.combatant.hp, 5000, "Airborne defender cannot be thrown")

    var attacking := _battle()
    var light := InputFrame.InputButton.LIGHT
    _tick(attacking, _heavy(1, 1), InputFrame.new(1, 0, 0, light, light, 0))
    for _i in range(5):
        _tick(attacking)
    t.equal(attacking.fighter_b.combatant.hp, 5000, "GROUND_ATTACK defender is not throwable")

func _test_throw_duplicate_contact() -> void:
    var battle := _battle()
    _tick(battle, _heavy(1, 1), _guard(1))
    for _i in range(12):
        var f := battle.frame_number + 1
        _tick(battle, InputFrame.neutral(f), _guard(f))
    var throw_events := 0
    for event in battle.peek_events():
        if event.type == CombatEvent.EventType.THROW:
            throw_events += 1
    t.equal(throw_events, 1, "Throw active duplicate contact only succeeds once per AttackInstanceID")
    t.equal(battle.fighter_b.combatant.hp, 4880, "Throw duplicate protection prevents repeated damage")

func _test_dash_recognition_windows() -> void:
    var dash := _battle(30000, 100000)
    _tick(dash, _dir(1, 1))
    _tick(dash, _dir(2, 0))
    _tick(dash, _dir(3, 1))
    t.equal(dash.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "Forward-neutral-forward <=12F starts Dash")

    var back := _battle(30000, 100000)
    _tick(back, _dir(1, -1))
    _tick(back, _dir(2, 0))
    _tick(back, _dir(3, -1))
    t.equal(back.fighter_a.state_machine.state, FighterStateMachine.State.BACKSTEP, "Back-neutral-back <=12F starts Backstep")

    var late := _battle(30000, 100000)
    _tick(late, _dir(1, 1))
    for _i in range(12):
        _tick(late, _dir(late.frame_number + 1, 0))
    _tick(late, _dir(late.frame_number + 1, 1))
    t.that(late.fighter_a.state_machine.state != FighterStateMachine.State.DASH_FORWARD, "Second tap too late does not Dash")

    var neutral_gap := _battle(30000, 100000)
    _tick(neutral_gap, _dir(1, 1))
    for _i in range(7):
        _tick(neutral_gap, _dir(neutral_gap.frame_number + 1, 0))
    _tick(neutral_gap, _dir(neutral_gap.frame_number + 1, 1))
    t.that(neutral_gap.fighter_a.state_machine.state != FighterStateMachine.State.DASH_FORWARD, "Neutral gap >6F does not Dash")

    var held := _battle(30000, 100000)
    for f in range(1, 8):
        _tick(held, _dir(f, 1))
    t.that(held.fighter_a.state_machine.state != FighterStateMachine.State.DASH_FORWARD, "Holding direction does not spam Dash")

func _test_dash_relative_facing_and_exact_movement() -> void:
    var facing_left := _battle(80000, 50000)
    t.equal(facing_left.fighter_a.movement_motor.facing, -1, "P1 starts facing left when opponent is to world-left")
    _tick(facing_left, _dir(1, -1))
    _tick(facing_left, _dir(2, 0))
    _tick(facing_left, _dir(3, -1))
    t.equal(facing_left.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "Facing left reverses world direction meaning for Dash")

    var exact := _battle(30000, 100000)
    _tick(exact, _dir(1, 1))
    _tick(exact, _dir(2, 0))
    var before_second_tap := exact.fighter_a.movement_motor.sim_position.x
    _tick(exact, _dir(3, 1))
    for _i in range(7):
        _tick(exact)
    t.equal(exact.fighter_a.movement_motor.sim_position.x - before_second_tap, character.dash_speed_units_per_tick * character.dash_move_frames, "Dash movement lasts exact configured 8F")
    t.equal(exact.fighter_a.state_machine.dash_move_remaining, 0, "Dash movement timer reaches zero after exact movement frames")
    var recovery_x := exact.fighter_a.movement_motor.sim_position.x
    for _i in range(character.dash_recovery_frames):
        _tick(exact)
    t.equal(exact.fighter_a.movement_motor.sim_position.x, recovery_x, "Dash recovery has no movement")
    t.equal(exact.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Dash recovery lasts exact 4F then returns Idle")

    var backstep := _battle(60000, 100000)
    _tick(backstep, _dir(1, -1))
    _tick(backstep, _dir(2, 0))
    var back_before := backstep.fighter_a.movement_motor.sim_position.x
    _tick(backstep, _dir(3, -1))
    for _i in range(6):
        _tick(backstep)
    t.equal(back_before - backstep.fighter_a.movement_motor.sim_position.x, character.backstep_speed_units_per_tick * character.backstep_move_frames, "Backstep movement lasts exact configured 7F")
    var back_recovery_x := backstep.fighter_a.movement_motor.sim_position.x
    for _i in range(character.backstep_recovery_frames):
        _tick(backstep)
    t.equal(backstep.fighter_a.movement_motor.sim_position.x, back_recovery_x, "Backstep recovery has no movement")
    t.equal(backstep.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Backstep recovery lasts exact 6F")

func _test_dash_stage_hit_ko_rules() -> void:
    var edge := _battle(BattleSimulation.STAGE_RIGHT_UNITS - 1000, 20000)
    edge.fighter_a.movement_motor.facing = 1
    _tick(edge, _dir(1, 1))
    _tick(edge, _dir(2, 0))
    _tick(edge, _dir(3, 1))
    t.equal(edge.fighter_a.movement_motor.sim_position.x, BattleSimulation.STAGE_RIGHT_UNITS, "Dash respects stage boundary clamp")

    var interrupted := _battle(30000, 100000)
    _tick(interrupted, _dir(1, 1))
    _tick(interrupted, _dir(2, 0))
    _tick(interrupted, _dir(3, 1))
    interrupted.fighter_a.combatant.receive_hit(0, 5, 0, 0, 0)
    _tick(interrupted)
    t.equal(interrupted.fighter_a.state_machine.state, FighterStateMachine.State.HITSTUN, "Hit interrupts Dash")

    var ko := _battle(30000, 100000)
    ko.fighter_a.combatant.hp = 0
    ko.fighter_a.combatant.is_ko = true
    _tick(ko, _dir(1, 1))
    _tick(ko, _dir(2, 0))
    _tick(ko, _dir(3, 1))
    t.equal(ko.fighter_a.state_machine.state, FighterStateMachine.State.KO, "KO cannot Dash")
