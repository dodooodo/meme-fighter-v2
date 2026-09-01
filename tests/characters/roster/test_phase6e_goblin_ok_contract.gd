# Phase 6E real-runtime throw/capture contracts for Goblin Love and OK Meow Boss.
class_name Phase6EGoblinOkContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")

var t = ASSERT_HELPER.new()
var goblin: CharacterData
var ok: CharacterData
var generic: CharacterData

func run_all() -> int:
    goblin = RosterRegistry.character_by_id(&"goblin_love")
    ok = RosterRegistry.character_by_id(&"ok_meow_boss")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_goblin_command_grab_ladder_and_snapshot()
    _test_ok_ground_capture_pressure_and_snapshot()
    _test_normal_throw_tech_cross_character_regression()
    print("\nPhase 6E Goblin/OK contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData, ax: int = 50000, bx: int = 61500) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _input(frame: int, x: int = 0, y: int = 0, buttons: int = 0) -> InputFrame:
    return InputFrame.new(frame, x, y, buttons, 0, 0)

func _move(fighter: Fighter, id: StringName) -> MoveData:
    return fighter.move_registry.get_move(id)

func _start_move_at_frame(fighter: Fighter, id: StringName, frame: int) -> MoveData:
    var move := _move(fighter, id)
    fighter.move_runner.interrupt()
    if move != null:
        fighter.move_runner.start_move(move)
        fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
        fighter.state_machine.transition_to(FighterStateMachine.State.THROW if move.throw_box != null else FighterStateMachine.State.GROUND_ATTACK)
        fighter.move_runner.move_frame = frame
    return move

func _start_active(fighter: Fighter, id: StringName) -> MoveData:
    var move := _move(fighter, id)
    return _start_move_at_frame(fighter, id, move.first_active_frame() if move != null else 0)

func _event_count(battle: BattleSimulation, type: int) -> int:
    var count := 0
    for event: CombatEvent in battle.drain_events():
        if event.type == type:
            count += 1
    return count

func _test_goblin_command_grab_ladder_and_snapshot() -> void:
    var l1 := _move(_battle(goblin, generic).fighter_a, &"goblin_grab_l1")
    var l2 := _move(_battle(goblin, generic).fighter_a, &"goblin_grab_l2")
    var l3 := _move(_battle(goblin, generic).fighter_a, &"goblin_grab_l3")
    t.equal(l1.startup_frames, 7, "Goblin Lv1 command grab has authored 7F startup")
    t.equal(l1.damage, 115, "Goblin Lv1 command grab retains 115 damage")
    t.equal(l1.throw_whiff_recovery_frames, 28, "Goblin Lv1 command grab retains 28F whiff recovery")
    t.equal(l2.startup_frames, 9, "Goblin Lv2 command grab has authored 9F startup")
    t.equal(l2.damage, 145, "Goblin Lv2 command grab retains 145 damage")
    t.equal(l2.throw_whiff_recovery_frames, 32, "Goblin Lv2 command grab retains 32F whiff recovery")
    t.equal(l3.startup_frames, 12, "Goblin Lv3 command grab has authored 12F startup")
    t.equal(l3.damage, 185, "Goblin Lv3 command grab retains 185 damage")
    t.equal(l3.throw_whiff_recovery_frames, 38, "Goblin Lv3 command grab retains 38F whiff recovery")
    t.equal(l3.reaction_type, CombatReaction.Type.HARD_KNOCKDOWN, "Goblin Lv3 command grab retains Hard Knockdown")
    t.that(l1.armor_data == null and l2.armor_data == null and l3.armor_data == null, "Goblin command-grab ladder has no armor")

    var guarded := _battle(goblin, generic)
    _start_active(guarded.fighter_a, &"goblin_grab_l1")
    _tick(guarded, null, _input(guarded.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD))
    t.equal(_event_count(guarded, CombatEvent.EventType.THROW), 1, "Goblin Lv1 command grab succeeds through Guard")

    var outside := _battle(goblin, generic, 50000, 62200)
    _start_active(outside.fighter_a, &"goblin_grab_l1")
    _tick(outside)
    t.equal(_event_count(outside, CombatEvent.EventType.THROW), 0, "Goblin Lv1 whiffs just outside its 120px-effective range")

    var jump_escape := _battle(goblin, generic)
    _start_active(jump_escape.fighter_a, &"goblin_grab_l1")
    _tick(jump_escape, null, _input(jump_escape.frame_number + 1, 0, 1))
    t.equal(_event_count(jump_escape, CombatEvent.EventType.THROW), 0, "Goblin command grab cannot capture an airborne defender")

    var strike_interrupt := _battle(goblin, generic)
    _start_move_at_frame(strike_interrupt.fighter_a, &"goblin_grab_l3", 1)
    _start_active(strike_interrupt.fighter_b, MoveIds.STAND_LIGHT)
    _tick(strike_interrupt)
    t.that(strike_interrupt.fighter_a.combatant.hitstun_remaining > 0, "Goblin startup is interrupted by a real fast strike without armor")

    var backstep_escape := _battle(goblin, generic)
    _start_move_at_frame(backstep_escape.fighter_a, &"goblin_grab_l3", 1)
    _tick(backstep_escape, null, _input(backstep_escape.frame_number + 1, 1))
    _tick(backstep_escape, null, _input(backstep_escape.frame_number + 1, 0))
    _tick(backstep_escape, null, _input(backstep_escape.frame_number + 1, 1))
    backstep_escape.fighter_a.move_runner.move_frame = l3.first_active_frame()
    _tick(backstep_escape)
    t.equal(_event_count(backstep_escape, CombatEvent.EventType.THROW), 0, "Goblin command grab respects real pre-active Backstep escape")

    var low := _move(_battle(goblin, generic).fighter_a, MoveIds.CROUCH_LOW)
    t.equal(low.cancel_windows.size(), 0, "Goblin Low has no protected direct command-grab cancel routing")

    var snapshot_battle := _battle(goblin, generic)
    _start_move_at_frame(snapshot_battle.fighter_a, &"goblin_grab_l3", 5)
    var snapshot := snapshot_battle.capture_state()
    for _i in range(8): _tick(snapshot_battle)
    var hash_a := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "Goblin pending command grab snapshot restores")
    for _i in range(8): _tick(snapshot_battle)
    t.equal(snapshot_battle.state_signature(), hash_a, "Goblin command grab replay restores identical hash")

func _test_ok_ground_capture_pressure_and_snapshot() -> void:
    var probe := _battle(ok, generic)
    var capture := _move(probe.fighter_a, MoveIds.ULTIMATE)
    t.equal(capture.throw_kind, MoveData.ThrowKind.GROUND_CAPTURE_SUPER, "OK Ultimate remains data-defined Ground Capture Super")
    t.equal(capture.throw_whiff_recovery_frames, 42, "OK Capture retains 42F whiff recovery")
    t.equal(capture.throw_conditions.size(), 3, "OK Capture retains grounded, throwable, and ordinary-hitstun conditions")

    var grounded := _battle(ok, generic)
    _start_active(grounded.fighter_a, MoveIds.ULTIMATE)
    _tick(grounded)
    t.equal(_event_count(grounded, CombatEvent.EventType.THROW), 1, "OK raw Ground Capture succeeds on a near grounded throwable target")

    var airborne := _battle(ok, generic)
    _start_active(airborne.fighter_a, MoveIds.ULTIMATE)
    _tick(airborne, null, _input(airborne.frame_number + 1, 0, 1))
    t.equal(_event_count(airborne, CombatEvent.EventType.THROW), 0, "OK Ground Capture cannot capture an airborne target")

    var out_of_range := _battle(ok, generic, 50000, 70000)
    _start_active(out_of_range.fighter_a, MoveIds.ULTIMATE)
    _tick(out_of_range)
    t.equal(_event_count(out_of_range, CombatEvent.EventType.THROW), 0, "OK Ground Capture whiffs outside authored near range")

    for id: StringName in [MoveIds.STAND_LIGHT, MoveIds.STAND_HEAVY, MoveIds.CROUCH_LOW]:
        var hit_combo := _battle(ok, generic, 50000, 55000)
        _start_active(hit_combo.fighter_a, id)
        _tick(hit_combo)
        t.equal(_event_count(hit_combo, CombatEvent.EventType.HIT), 1, "OK ordinary %s test begins with a real hit" % String(id))
        _start_active(hit_combo.fighter_a, MoveIds.ULTIMATE)
        _tick(hit_combo)
        t.equal(_event_count(hit_combo, CombatEvent.EventType.THROW), 0, "OK ordinary %s hit does not guarantee Ground Capture" % String(id))

    var expected_advantage := {&"ok_pressure_l1": -2, &"ok_pressure_l2": 1, &"ok_pressure_l3": 2}
    for id: StringName in expected_advantage:
        var special := _move(probe.fighter_a, id)
        t.equal(special.blockstun_frames - special.recovery_frames, expected_advantage[id], "OK %s has authored target block advantage" % String(id))
        t.that(special.defender_block_pushback_units >= (1500 if id != &"ok_pressure_l1" else 0), "OK %s retains authored counterplay pushback" % String(id))
        t.equal(special.cancel_windows.size(), 0, "Blocked OK %s has no protected Capture cancel" % String(id))
        var blocked := _battle(ok, generic, 50000, 60000)
        var before_distance := absi(blocked.fighter_a.movement_motor.sim_position.x - blocked.fighter_b.movement_motor.sim_position.x)
        _start_active(blocked.fighter_a, id)
        _tick(blocked, null, _input(blocked.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD))
        t.equal(_event_count(blocked, CombatEvent.EventType.BLOCK), 1, "OK %s follows its actual guard interaction" % String(id))
        if id != &"ok_pressure_l1":
            var after_distance := absi(blocked.fighter_a.movement_motor.sim_position.x - blocked.fighter_b.movement_motor.sim_position.x)
            t.that(after_distance > before_distance, "OK %s block pushback creates real capture counterplay distance" % String(id))

    var snapshot_battle := _battle(ok, generic)
    _start_move_at_frame(snapshot_battle.fighter_a, MoveIds.ULTIMATE, 7)
    var snapshot := snapshot_battle.capture_state()
    for _i in range(12): _tick(snapshot_battle)
    var hash_a := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "OK Capture startup snapshot restores")
    for _i in range(12): _tick(snapshot_battle)
    t.equal(snapshot_battle.state_signature(), hash_a, "OK Capture replay restores identical hash")

func _test_normal_throw_tech_cross_character_regression() -> void:
    for character: CharacterData in [goblin, ok, generic]:
        var battle := _battle(character, generic, 50000, 58000)
        _start_active(battle.fighter_a, MoveIds.GROUND_THROW)
        _start_active(battle.fighter_b, MoveIds.GROUND_THROW)
        _tick(battle)
        t.equal(_event_count(battle, CombatEvent.EventType.THROW_TECH), 1, "%s normal Throw remains techable" % character.id)
