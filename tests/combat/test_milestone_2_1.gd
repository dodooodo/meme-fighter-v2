# Responsibility: M2.1 Stand Heavy, generic normal-action request, buffer, and trade regression suite.
# Owns: M2.1 tests only.
# Does NOT own: production combat behavior, data mutation outside isolated test setup, presentation.
# Dependencies: BattleSimulation, MoveRegistry, InputBuffer, MoveIds, InputFrame.
class_name Milestone21Tests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_heavy_exists_and_registry_lookup()
    _test_heavy_frame_data()
    _test_heavy_startup_and_first_active_hit()
    _test_heavy_hitstop_freezes_timeline()
    _test_heavy_duplicate_hit_protection()
    _test_heavy_returns_idle_and_frame_36_is_actionable()
    _test_light_data_regression_and_action_selection()
    _test_buffered_light_executes_after_recovery()
    _test_buffered_heavy_executes_after_recovery()
    _test_early_buffer_expires()
    _test_latest_input_wins()
    _test_consumed_buffer_does_not_repeat()
    _test_ko_clears_and_blocks_buffer()
    _test_hitstun_clears_buffer()
    _test_mixed_light_heavy_trade()
    print("\nM2.1 Ground Combat Expansion tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 50000, p2_x: int = 58000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        character,
        character,
        null,
        null,
        Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS)
    )
    return battle

func _neutral(frame: int) -> InputFrame:
    return InputFrame.neutral(frame)

func _light(frame: int) -> InputFrame:
    return InputFrame.with_light_press(frame)

func _heavy(frame: int) -> InputFrame:
    return InputFrame.with_heavy_press(frame)

func _tick_neutral(battle: BattleSimulation, count: int) -> void:
    for _i in range(count):
        var frame := battle.frame_number + 1
        battle.simulate_frame(_neutral(frame), _neutral(frame))

func _start_p1_light(battle: BattleSimulation) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(_light(frame), _neutral(frame))

func _start_p1_heavy(battle: BattleSimulation) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(_heavy(frame), _neutral(frame))

func _advance_p1_to_move_frame(battle: BattleSimulation, target_move_frame: int) -> void:
    while battle.fighter_a.move_runner.is_running() and battle.fighter_a.move_runner.move_frame < target_move_frame:
        _tick_neutral(battle, 1)

func _registry() -> MoveRegistry:
    var registry := MoveRegistry.new()
    registry.configure(character.move_set)
    return registry

func _test_heavy_exists_and_registry_lookup() -> void:
    var registry := _registry()
    t.that(registry.has_move(MoveIds.STAND_HEAVY), "Generic Fighter MoveSet contains Stand Heavy")
    var heavy := registry.get_move(MoveIds.STAND_HEAVY)
    t.that(heavy != null and heavy.id == MoveIds.STAND_HEAVY, "Registry retrieves STAND_HEAVY by stable ID")

func _test_heavy_frame_data() -> void:
    var heavy := _registry().get_move(MoveIds.STAND_HEAVY)
    t.equal(heavy.startup_frames, 11, "Stand Heavy startup is exactly 11F")
    t.equal(heavy.active_frames, 4, "Stand Heavy active is exactly 4F")
    t.equal(heavy.recovery_frames, 20, "Stand Heavy recovery is exactly 20F")
    t.equal(heavy.first_active_frame(), 12, "Stand Heavy first active frame is 12")
    t.equal(heavy.last_active_frame(), 15, "Stand Heavy active frames are 12-15")
    t.equal(heavy.total_frames(), 35, "Stand Heavy frame 36 is actionable")
    t.equal(heavy.damage, 95, "Stand Heavy damage is 95")
    t.equal(heavy.hitstun_frames, 19, "Stand Heavy hitstun is 19F")
    t.equal(heavy.blockstun_frames, 13, "Stand Heavy blockstun data is 13F")
    t.equal(heavy.hitstop_attacker, 6, "Stand Heavy attacker hitstop is 6F")
    t.equal(heavy.hitstop_defender, 6, "Stand Heavy defender hitstop is 6F")
    t.equal(heavy.knockback_y_units, 0, "Stand Heavy has no vertical launch")

func _test_heavy_startup_and_first_active_hit() -> void:
    var battle := _battle()
    _start_p1_heavy(battle)
    _tick_neutral(battle, 10) # frame 11 collision has completed; next is first Active.
    t.equal(battle.fighter_b.combatant.hp, 1000, "Heavy cannot hit during startup frames 1-11")
    _tick_neutral(battle, 1) # move frame 12 collision
    t.equal(battle.fighter_b.combatant.hp, 905, "Heavy hits for 95 on first active frame 12")
    t.equal(battle.fighter_b.combatant.hitstun_remaining, 19, "Heavy applies 19F hitstun before hitstop elapses")

func _test_heavy_hitstop_freezes_timeline() -> void:
    var battle := _battle()
    _start_p1_heavy(battle)
    _tick_neutral(battle, 11) # hit on move frame 12
    t.equal(battle.fighter_a.move_runner.move_frame, 12, "Heavy attacker remains on frame 12 when hitstop starts")
    _tick_neutral(battle, 5)
    t.equal(battle.fighter_a.move_runner.move_frame, 12, "6F Heavy hitstop freezes MoveRunner timeline")
    _tick_neutral(battle, 1)
    t.equal(battle.fighter_a.move_runner.move_frame, 13, "Heavy timeline resumes after 6F hitstop")

func _test_heavy_duplicate_hit_protection() -> void:
    var battle := _battle()
    _start_p1_heavy(battle)
    _tick_neutral(battle, 11)
    var hp_after_hit := battle.fighter_b.combatant.hp
    _tick_neutral(battle, 12)
    t.equal(hp_after_hit, 905, "Heavy first contact deals exactly 95 damage")
    t.equal(battle.fighter_b.combatant.hp, 905, "Heavy four-frame Active overlap damages once per AttackInstanceID")

func _test_heavy_returns_idle_and_frame_36_is_actionable() -> void:
    var battle := _battle(40000, 100000)
    _start_p1_heavy(battle)
    _tick_neutral(battle, 34) # frame 35 completes and post-tick returns Idle.
    t.that(not battle.fighter_a.move_runner.is_running(), "Heavy completes after frame 35")
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Heavy recovery returns fighter to Idle")
    var frame := battle.frame_number + 1 # simulation frame corresponding to actionable move frame 36
    battle.simulate_frame(_light(frame), _neutral(frame))
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Fighter can start a new move on Heavy frame 36 actionable point")

func _test_light_data_regression_and_action_selection() -> void:
    var registry := _registry()
    var light := registry.get_move(MoveIds.STAND_LIGHT)
    t.equal(light.startup_frames, 5, "Stand Light startup remains 5F")
    t.equal(light.active_frames, 3, "Stand Light active remains 3F")
    t.equal(light.recovery_frames, 10, "Stand Light recovery remains 10F")
    t.equal(light.damage, 50, "Stand Light damage remains 50")
    t.equal(light.hitstun_frames, 14, "Stand Light hitstun remains 14F")
    t.equal(light.hitstop_attacker, 4, "Stand Light hitstop remains 4F")

    var light_battle := _battle(40000, 100000)
    _start_p1_light(light_battle)
    t.equal(light_battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "LIGHT request selects STAND_LIGHT")

    var heavy_battle := _battle(40000, 100000)
    _start_p1_heavy(heavy_battle)
    t.equal(heavy_battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "HEAVY request selects STAND_HEAVY")

func _test_buffered_light_executes_after_recovery() -> void:
    var battle := _battle(40000, 100000)
    _start_p1_light(battle)
    _advance_p1_to_move_frame(battle, 16)
    var request_frame := battle.frame_number + 1
    battle.simulate_frame(_light(request_frame), _neutral(request_frame))
    var buffered_light := battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(buffered_light != null, "Light buffers with 3F recovery remaining")
    t.equal(buffered_light.action_button, InputFrame.InputButton.LIGHT, "Buffered Light keeps LIGHT action intent")
    _tick_neutral(battle, 3)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Buffered Light starts when recovery becomes actionable")
    t.that(not battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Buffered Light is consumed on start")

func _test_buffered_heavy_executes_after_recovery() -> void:
    var battle := _battle(40000, 100000)
    _start_p1_light(battle)
    _advance_p1_to_move_frame(battle, 16)
    var request_frame := battle.frame_number + 1
    battle.simulate_frame(_heavy(request_frame), _neutral(request_frame))
    var buffered_heavy := battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(buffered_heavy != null, "Heavy buffers with 3F recovery remaining")
    t.equal(buffered_heavy.action_button, InputFrame.InputButton.HEAVY, "Buffered Heavy keeps HEAVY action intent")
    _tick_neutral(battle, 3)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Buffered Heavy starts when recovery becomes actionable")

func _test_early_buffer_expires() -> void:
    var battle := _battle(40000, 100000)
    _start_p1_light(battle)
    _advance_p1_to_move_frame(battle, 12)
    var request_frame := battle.frame_number + 1
    battle.simulate_frame(_light(request_frame), _neutral(request_frame))
    t.that(battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Early Light initially enters buffer")
    _tick_neutral(battle, 7)
    t.that(not battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Input older than 5F buffer window expires")
    t.that(not battle.fighter_a.move_runner.is_running(), "Expired Light does not execute after recovery")

func _test_latest_input_wins() -> void:
    var battle := _battle(40000, 100000)
    _start_p1_light(battle)
    _advance_p1_to_move_frame(battle, 16)
    var frame := battle.frame_number + 1
    battle.simulate_frame(_light(frame), _neutral(frame))
    frame = battle.frame_number + 1
    battle.simulate_frame(_heavy(frame), _neutral(frame))
    var latest_intent := battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(latest_intent != null, "Latest normal input remains buffered")
    t.equal(latest_intent.action_button, InputFrame.InputButton.HEAVY, "Latest normal input replaces previous buffered action")
    _tick_neutral(battle, 2)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Latest-input-wins executes Heavy, not earlier Light")

func _test_consumed_buffer_does_not_repeat() -> void:
    var battle := _battle(40000, 100000)
    _start_p1_light(battle)
    _advance_p1_to_move_frame(battle, 16)
    var request_frame := battle.frame_number + 1
    battle.simulate_frame(_heavy(request_frame), _neutral(request_frame))
    _tick_neutral(battle, 3)
    var buffered_attack_instance := battle.fighter_a.move_runner.attack_instance_id
    t.that(not battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Consumed Heavy leaves no stale buffer")
    _tick_neutral(battle, 38)
    t.that(not battle.fighter_a.move_runner.is_running(), "Consumed buffered Heavy completes normally")
    t.equal(battle.fighter_a.move_runner.attack_instance_id, buffered_attack_instance, "Consumed buffer does not start the action a second time")

func _test_ko_clears_and_blocks_buffer() -> void:
    var battle := _battle(40000, 100000)
    battle.fighter_a.input_buffer.buffer_intent(ActionIntent.new(InputFrame.InputButton.LIGHT, 1))
    battle.fighter_a.combatant.hp = 0
    battle.fighter_a.combatant.is_ko = true
    battle.simulate_frame(_neutral(1), _neutral(1))
    t.that(not battle.fighter_a.input_buffer.has_pending(battle.frame_number), "KO clears normal attack buffer")
    t.that(not battle.fighter_a.move_runner.is_running(), "KO fighter cannot execute buffered attack")
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.KO, "KO legality remains authoritative over buffer")

func _test_hitstun_clears_buffer() -> void:
    var battle := _battle(40000, 100000)
    battle.fighter_a.input_buffer.buffer_intent(ActionIntent.new(InputFrame.InputButton.HEAVY, 1))
    battle.fighter_a.combatant.hitstun_remaining = 5
    battle.simulate_frame(_neutral(1), _neutral(1))
    t.that(not battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Hitstun clears normal attack buffer")
    t.that(not battle.fighter_a.move_runner.is_running(), "Hitstun cannot execute buffered Heavy")
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.HITSTUN, "Hitstun state remains authoritative over buffer")

func _test_mixed_light_heavy_trade() -> void:
    var battle := _battle(50000, 58000)
    var frame := battle.frame_number + 1
    battle.simulate_frame(_neutral(frame), _heavy(frame)) # P2 Heavy starts six frames before P1 Light.
    _tick_neutral(battle, 5)
    frame = battle.frame_number + 1
    battle.simulate_frame(_light(frame), _neutral(frame))
    _tick_neutral(battle, 5) # P1 Light frame 6 and P2 Heavy frame 12 become active together.
    t.equal(battle.fighter_a.combatant.hp, 905, "Mixed trade applies P2 Heavy result to P1")
    t.equal(battle.fighter_b.combatant.hp, 950, "Mixed trade applies P1 Light result to P2")
