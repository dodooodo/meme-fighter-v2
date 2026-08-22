# Responsibility: M2.4 THROWN -> KNOCKDOWN -> GETUP forced-reaction regression suite.
# Owns tests only; forced-reaction timers/state policy live in FighterStateMachine.
class_name Milestone24KnockdownTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_thrown_knockdown_getup_durations()
    _test_getup_protection()
    _test_getup_completion_posture_rules()
    _test_ko_overrides_forced_reactions()
    print("\nM2.4 Knockdown/GetUp tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle() -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(character, character, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(58000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _guard(frame: int, down: bool = false) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, -1 if down else 0, bit, bit, 0)

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _make_thrown() -> BattleSimulation:
    var battle := _battle()
    _tick(battle, InputFrame.with_heavy_press(1, 1), _guard(1))
    for _i in range(5):
        var f := battle.frame_number + 1
        _tick(battle, InputFrame.neutral(f), _guard(f))
    battle.fighter_a.combatant.hitstop_remaining = 0
    battle.fighter_b.combatant.hitstop_remaining = 0
    return battle

func _test_thrown_knockdown_getup_durations() -> void:
    var battle := _make_thrown()
    t.equal(battle.fighter_b.combatant.hp, 4880, "Throw damage = 120 before forced reaction flow")
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.THROWN, "Throw success enters THROWN")
    t.equal(battle.fighter_b.state_machine.thrown_remaining, 10, "THROWN starts with correct 10F duration")
    for _i in range(9):
        _tick(battle)
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.THROWN, "THROWN remains active through first 9 hold frames")
    t.equal(battle.fighter_b.state_machine.thrown_remaining, 1, "THROWN timer reaches 1 before final hold frame")
    _tick(battle)
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.KNOCKDOWN, "THROWN transitions to KNOCKDOWN after 10F")
    t.equal(battle.fighter_b.state_machine.knockdown_remaining, 30, "KNOCKDOWN starts with correct 30F duration")

    for _i in range(29):
        _tick(battle)
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.KNOCKDOWN, "KNOCKDOWN remains active through first 29 frames")
    _tick(battle)
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.GETUP, "KNOCKDOWN transitions to GETUP")
    t.equal(battle.fighter_b.state_machine.getup_remaining, 18, "GETUP starts with configured 18F duration")

    for _i in range(17):
        _tick(battle)
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.GETUP, "GETUP remains locked through first 17 frames")
    _tick(battle)
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.IDLE, "GETUP lasts 18F then returns Idle on neutral")

func _test_getup_protection() -> void:
    var battle := _battle()
    battle.fighter_b.state_machine.state = FighterStateMachine.State.GETUP
    battle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.HIT_REACTION
    battle.fighter_b.state_machine.getup_remaining = 10
    t.that(not battle.fighter_b.state_machine.is_strike_target(), "GETUP rejects strikes via temporary state-level greybox protection")
    t.that(not battle.fighter_b.state_machine.is_throwable(), "GETUP rejects throws via temporary state-level greybox protection")

    var light := battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT)
    battle.fighter_a.move_runner.start_move(light)
    battle.fighter_a.move_runner.move_frame = light.first_active_frame()
    var strike := battle.collision_system.build_strike_contact(battle.fighter_a, battle.fighter_b)
    t.that(strike == null, "CollisionSystem does not build strike contact against GETUP")

    var throw_move := battle.fighter_a.move_registry.get_move(MoveIds.GROUND_THROW)
    battle.fighter_a.move_runner.interrupt()
    battle.fighter_a.move_runner.start_move(throw_move)
    battle.fighter_a.move_runner.move_frame = throw_move.first_active_frame()
    var throw_contact := battle.throw_system.build_throw_contact(battle.fighter_a, battle.fighter_b)
    t.that(throw_contact == null, "ThrowSystem does not build ThrowContact against GETUP")

func _test_getup_completion_posture_rules() -> void:
    var guard_battle := _battle()
    guard_battle.fighter_b.state_machine.state = FighterStateMachine.State.GETUP
    guard_battle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.HIT_REACTION
    guard_battle.fighter_b.state_machine.getup_remaining = 1
    _tick(guard_battle, null, _guard(1))
    t.equal(guard_battle.fighter_b.state_machine.state, FighterStateMachine.State.GUARD, "GetUp returns Standing Guard if Guard held")
    t.equal(guard_battle.fighter_b.state_machine.guard_posture, FighterStateMachine.GuardPosture.STANDING, "GetUp Guard posture is Standing without Down")

    var crouch_guard := _battle()
    crouch_guard.fighter_b.state_machine.state = FighterStateMachine.State.GETUP
    crouch_guard.fighter_b.state_machine.root_state = FighterStateMachine.RootState.HIT_REACTION
    crouch_guard.fighter_b.state_machine.getup_remaining = 1
    _tick(crouch_guard, null, _guard(1, true))
    t.equal(crouch_guard.fighter_b.state_machine.state, FighterStateMachine.State.GUARD, "GetUp returns Guard if Guard+Down held")
    t.equal(crouch_guard.fighter_b.state_machine.guard_posture, FighterStateMachine.GuardPosture.CROUCHING, "GetUp Guard+Down returns Crouching Guard")

    var crouch := _battle()
    crouch.fighter_b.state_machine.state = FighterStateMachine.State.GETUP
    crouch.fighter_b.state_machine.root_state = FighterStateMachine.RootState.HIT_REACTION
    crouch.fighter_b.state_machine.getup_remaining = 1
    _tick(crouch, null, InputFrame.new(1, 0, -1, 0, 0, 0))
    t.equal(crouch.fighter_b.state_machine.state, FighterStateMachine.State.CROUCH, "GetUp returns Crouch if Down held")

    var idle := _battle()
    idle.fighter_b.state_machine.state = FighterStateMachine.State.GETUP
    idle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.HIT_REACTION
    idle.fighter_b.state_machine.getup_remaining = 1
    var light_bit := InputFrame.InputButton.LIGHT
    _tick(idle, null, InputFrame.new(1, 0, 0, light_bit, light_bit, 0))
    t.equal(idle.fighter_b.state_machine.state, FighterStateMachine.State.IDLE, "GetUp returns Idle otherwise")
    t.that(not idle.fighter_b.move_runner.is_running(), "GetUp completion does not auto-execute buffered wakeup attack")

func _test_ko_overrides_forced_reactions() -> void:
    for forced_state in [FighterStateMachine.State.THROWN, FighterStateMachine.State.KNOCKDOWN, FighterStateMachine.State.GETUP]:
        var battle := _battle()
        battle.fighter_b.state_machine.state = forced_state
        battle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.HIT_REACTION
        battle.fighter_b.combatant.hp = 0
        battle.fighter_b.combatant.is_ko = true
        _tick(battle)
        t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.KO, "KO overrides Throw/Knockdown/GetUp forced state")
