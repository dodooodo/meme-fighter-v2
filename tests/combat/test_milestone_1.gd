# Responsibility: Automated Milestone 0/1 combat regression suite.
# Owns: tests only.
# Does NOT own: production behavior or presentation.
# Dependencies: BattleSimulation and core data types.
class_name Milestone1Tests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_fixed_clock_render_rate_independence()
    _test_input_history_is_60_frame_circular_buffer()
    _test_light_data_and_frame_convention()
    _test_startup_cannot_hit_and_first_active_can_hit()
    _test_same_attack_instance_damages_only_once()
    _test_hitstun_blocks_normal_move_start()
    _test_hitstop_freezes_move_timeline()
    _test_move_returns_to_idle_after_recovery()
    _test_pushboxes_prevent_overlap()
    _test_ko_clamps_hp_and_blocks_attack()
    _test_combat_events_are_queued()
    _test_same_frame_trade_is_preserved()
    print("\nMilestone 0+1 tests: %d passed, %d failed" % [t.passed, t.failed])
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

func _neutral(frame: int, dir_x: int = 0) -> InputFrame:
    return InputFrame.new(frame, dir_x, 0, 0, 0, 0)

func _light(frame: int, dir_x: int = 0) -> InputFrame:
    return InputFrame.with_light_press(frame, dir_x)

func _tick_neutral(battle: BattleSimulation, count: int) -> void:
    for _i in range(count):
        var f := battle.frame_number + 1
        battle.simulate_frame(_neutral(f), _neutral(f))

func _start_p1_light(battle: BattleSimulation) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(_light(f), _neutral(f))

func _test_fixed_clock_render_rate_independence() -> void:
    t.equal(SimulationClock.FIXED_HZ, 60, "Combat scheduler constant is 60 Hz")
    var clock_30 := SimulationClock.new()
    var ticks_30 := 0
    for _i in range(30):
        ticks_30 += clock_30.consume_render_delta(1.0 / 30.0)
    var clock_120 := SimulationClock.new()
    var ticks_120 := 0
    for _i in range(120):
        ticks_120 += clock_120.consume_render_delta(1.0 / 120.0)
    t.equal(ticks_30, 60, "30 render FPS schedules 60 gameplay ticks in one second")
    t.equal(ticks_120, 60, "120 render FPS schedules 60 gameplay ticks in one second")

func _test_input_history_is_60_frame_circular_buffer() -> void:
    var history := InputHistory.new(60)
    for f in range(1, 71):
        history.push(_neutral(f))
    t.equal(history.count(), 60, "InputHistory retains fixed 60 frame capacity")
    t.equal(history.latest().frame_number, 70, "InputHistory latest frame is correct")
    t.equal(history.get_recent(59).frame_number, 11, "InputHistory oldest retained frame is correct after wrap")

func _test_light_data_and_frame_convention() -> void:
    var registry := MoveRegistry.new()
    t.that(registry.configure(character.move_set), "Generic Fighter MoveSet validates for frame-data regression")
    var light := registry.get_move(MoveIds.STAND_LIGHT)
    t.equal(light.startup_frames, 5, "Stand Light startup is 5F")
    t.equal(light.active_frames, 3, "Stand Light active is 3F")
    t.equal(light.recovery_frames, 10, "Stand Light recovery is 10F")
    t.equal(light.first_active_frame(), 6, "Stand Light first active frame is 6")
    t.equal(light.last_active_frame(), 8, "Stand Light last active frame is 8")
    t.equal(light.total_frames(), 18, "Stand Light frame 19 is actionable")

func _test_startup_cannot_hit_and_first_active_can_hit() -> void:
    var battle := _battle()
    _start_p1_light(battle) # move frame 1 occurs here
    _tick_neutral(battle, 4) # through move frame 5
    t.equal(battle.fighter_b.combatant.hp, 5000, "Light cannot hit during startup frames 1-5")
    _tick_neutral(battle, 1) # move frame 6 collision
    t.equal(battle.fighter_b.combatant.hp, 4950, "Light can hit on first active frame 6")
    t.equal(battle.fighter_b.combatant.hitstun_remaining, 14, "Hit applies configured 14F hitstun before hitstop elapses")

func _test_same_attack_instance_damages_only_once() -> void:
    var battle := _battle()
    _start_p1_light(battle)
    _tick_neutral(battle, 5) # hit on frame 6
    var hp_after_hit := battle.fighter_b.combatant.hp
    _tick_neutral(battle, 12) # remains overlapped across frozen/active frames
    t.equal(hp_after_hit, 4950, "First contact deals exactly 50 damage")
    t.equal(battle.fighter_b.combatant.hp, 4950, "Same AttackInstanceID cannot damage same defender twice")

func _test_hitstun_blocks_normal_move_start() -> void:
    var battle := _battle()
    _start_p1_light(battle)
    _tick_neutral(battle, 5)
    var f := battle.frame_number + 1
    battle.simulate_frame(_neutral(f), _light(f))
    t.that(not battle.fighter_b.move_runner.is_running(), "Hitstun fighter cannot start Stand Light")
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.HITSTUN, "Defender enters HITSTUN state")

func _test_hitstop_freezes_move_timeline() -> void:
    var battle := _battle()
    _start_p1_light(battle)
    _tick_neutral(battle, 5) # collision on move frame 6
    t.equal(battle.fighter_a.move_runner.move_frame, 6, "Attacker remains on hit frame when hitstop begins")
    _tick_neutral(battle, 3)
    t.equal(battle.fighter_a.move_runner.move_frame, 6, "4F hitstop does not advance move timeline")
    _tick_neutral(battle, 1)
    t.equal(battle.fighter_a.move_runner.move_frame, 7, "Move timeline resumes after hitstop expires")

func _test_move_returns_to_idle_after_recovery() -> void:
    var battle := _battle(40000, 90000) # whiff, no hitstop
    _start_p1_light(battle)
    _tick_neutral(battle, 17)
    t.that(not battle.fighter_a.move_runner.is_running(), "Move completes after frame 18")
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Move recovery returns fighter to Idle")

func _test_pushboxes_prevent_overlap() -> void:
    var battle := _battle(50000, 52000)
    _tick_neutral(battle, 1)
    var a_rect := battle.fighter_a.hitbox_owner.pushbox_rect(battle.fighter_a.position_pixels(), battle.fighter_a.movement_motor.facing)
    var b_rect := battle.fighter_b.hitbox_owner.pushbox_rect(battle.fighter_b.position_pixels(), battle.fighter_b.movement_motor.facing)
    t.that(not a_rect.intersects(b_rect), "Pushboxes separate overlapping fighters")

func _test_ko_clamps_hp_and_blocks_attack() -> void:
    var battle := _battle()
    battle.fighter_b.combatant.hp = 50
    _start_p1_light(battle)
    _tick_neutral(battle, 5)
    t.equal(battle.fighter_b.combatant.hp, 0, "KO damage clamps HP at lower bound 0")
    t.that(battle.fighter_b.combatant.is_ko, "HP 0 marks fighter KO")
    t.equal(battle.fighter_b.state_machine.state, FighterStateMachine.State.KO, "KO fighter enters KO state")
    var f := battle.frame_number + 1
    battle.simulate_frame(_neutral(f), _light(f))
    t.that(not battle.fighter_b.move_runner.is_running(), "KO fighter cannot start a move")

func _test_combat_events_are_queued() -> void:
    var battle := _battle()
    _start_p1_light(battle)
    var start_events := battle.drain_events()
    var found_move_started := false
    for event in start_events:
        if event.type == CombatEvent.EventType.MOVE_STARTED:
            found_move_started = true
    t.that(found_move_started, "MoveStarted is queued for presentation")
    _tick_neutral(battle, 5)
    var events := battle.drain_events()
    var found_hit := false
    for event in events:
        if event.type == CombatEvent.EventType.HIT:
            found_hit = true
    t.that(found_hit, "Hit event is queued after authoritative combat resolution")

func _test_same_frame_trade_is_preserved() -> void:
    var battle := _battle(50000, 58000)
    var f := battle.frame_number + 1
    battle.simulate_frame(_light(f), _light(f))
    _tick_neutral(battle, 5)
    t.equal(battle.fighter_a.combatant.hp, 4950, "Same-frame trade lets P2 hit P1")
    t.equal(battle.fighter_b.combatant.hp, 4950, "Same-frame trade lets P1 hit P2")
