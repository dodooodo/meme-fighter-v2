# Responsibility: M4 Rush Grappler move timeline, combat data, throw, movement, meter, and cancel behavior tests.
class_name Milestone4RushGrapplerTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData
var registry: MoveRegistry

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    registry = MoveRegistry.new()
    t.that(registry.configure(rush.move_set), "Rush MoveSet configures for combat tests")
    _test_move_runner_timelines()
    _test_rush_combat_data()
    _test_rush_ground_movement_runtime()
    _test_rush_damage_runtime()
    _test_rush_throw_runtime_and_range()
    _test_rush_cancel_graph()
    _test_rush_ultimate_meter_gate()
    print("\nM4 Rush Grappler tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData = null, b: CharacterData = null, ax: int = 50000, bx: int = 57000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a if a != null else rush, b if b != null else generic, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _guard(frame: int) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, 0, bit, bit, 0)

func _assert_timeline(move_id: StringName, startup: int, active: int, recovery: int) -> void:
    var move := registry.get_move(move_id)
    var runner := MoveRunner.new()
    runner.configure(1)
    t.that(runner.start_move(move), "%s starts through generic MoveRunner" % String(move_id))
    var startup_count := 0
    var active_count := 0
    var recovery_count := 0
    while runner.is_running():
        match runner.phase():
            &"STARTUP": startup_count += 1
            &"ACTIVE": active_count += 1
            &"RECOVERY": recovery_count += 1
        runner.finalize_tick(false)
    t.equal(startup_count, startup, "%s startup duration is exact" % String(move_id))
    t.equal(active_count, active, "%s active duration is exact" % String(move_id))
    t.equal(recovery_count, recovery, "%s recovery duration is exact" % String(move_id))
    t.equal(move.total_frames() + 1, startup + active + recovery + 1, "%s actionable frame follows total timeline" % String(move_id))

func _test_move_runner_timelines() -> void:
    _assert_timeline(MoveIds.STAND_LIGHT, 4, 3, 9)
    _assert_timeline(MoveIds.STAND_HEAVY, 9, 4, 18)
    _assert_timeline(MoveIds.CROUCH_LOW, 7, 3, 14)
    _assert_timeline(MoveIds.AIR_ATTACK, 5, 4, 11)
    _assert_timeline(MoveIds.GROUND_THROW, 5, 2, 20)
    _assert_timeline(MoveIds.SPECIAL_NEUTRAL, 8, 4, 15)
    _assert_timeline(MoveIds.ULTIMATE, 12, 5, 28)

func _test_rush_combat_data() -> void:
    var expected := {
        MoveIds.STAND_LIGHT: [45, 13, 9, 3, 3, MoveData.HitLevel.MID, 520, 0, 7, 3],
        MoveIds.STAND_HEAVY: [90, 18, 12, 5, 5, MoveData.HitLevel.MID, 900, 0, 11, 5],
        MoveIds.CROUCH_LOW: [55, 14, 10, 4, 4, MoveData.HitLevel.LOW, 560, 0, 9, 4],
        MoveIds.AIR_ATTACK: [65, 13, 9, 4, 4, MoveData.HitLevel.HIGH, 650, -300, 9, 4],
        MoveIds.SPECIAL_NEUTRAL: [100, 18, 11, 5, 5, MoveData.HitLevel.MID, 900, 0, 16, 7],
        MoveIds.ULTIMATE: [240, 26, 16, 9, 9, MoveData.HitLevel.MID, 1450, -450, 0, 0],
    }
    for move_id in expected.keys():
        var move := registry.get_move(move_id)
        var e: Array = expected[move_id]
        t.equal(move.damage, e[0], "%s damage" % String(move_id))
        t.equal(move.hitstun_frames, e[1], "%s hitstun" % String(move_id))
        t.equal(move.blockstun_frames, e[2], "%s blockstun" % String(move_id))
        t.equal(move.hitstop_attacker, e[3], "%s attacker hitstop" % String(move_id))
        t.equal(move.hitstop_defender, e[4], "%s defender hitstop" % String(move_id))
        t.equal(move.hit_level, e[5], "%s HitLevel" % String(move_id))
        t.equal(move.knockback_x_units, e[6], "%s knockback X" % String(move_id))
        t.equal(move.knockback_y_units, e[7], "%s knockback Y" % String(move_id))
        t.equal(move.meter_gain_on_hit, e[8], "%s HIT meter" % String(move_id))
        t.equal(move.meter_gain_on_block, e[9], "%s BLOCK meter" % String(move_id))
    var throw_move := registry.get_move(MoveIds.GROUND_THROW)
    t.equal(throw_move.damage, 150, "Rush Throw damage 150")
    t.equal(throw_move.hitstop_attacker, 5, "Rush Throw attacker hitstop 5")
    t.equal(throw_move.hitstop_defender, 5, "Rush Throw defender hitstop 5")
    t.equal(throw_move.throw_hold_frames, 12, "Rush THROWN duration 12F")
    t.equal(throw_move.knockdown_frames, 36, "Rush throw knockdown 36F")
    t.equal(throw_move.meter_gain_on_throw, 18, "Rush Throw meter +18")
    t.that(throw_move.hitbox == null and throw_move.throw_box != null, "Rush Throw has throw_box and no normal strike hitbox")

func _test_rush_ground_movement_runtime() -> void:
    var walk := _battle(rush, generic, 30000, 90000)
    _tick(walk, InputFrame.new(1, 1, 0, 0, 0, 0))
    t.equal(walk.fighter_a.movement_motor.sim_position.x, 30345, "Rush forward walk integrates +345 units in one tick")

    var dash := _battle(rush, generic, 30000, 90000)
    _tick(dash, InputFrame.new(1, 1, 0, 0, 0, 0))
    _tick(dash, InputFrame.neutral(2))
    _tick(dash, InputFrame.new(3, 1, 0, 0, 0, 0))
    t.equal(dash.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "Rush uses same double-tap parser to enter Dash")
    t.equal(dash.fighter_a.state_machine.dash_move_remaining, 6, "Rush Dash starts from 7F and advances one simulation tick")
    t.equal(dash.fighter_a.movement_motor.velocity_units.x, 1050, "Rush Dash runtime reads 1050 speed from CharacterData")

func _advance_attack_to_contact(battle: BattleSimulation, first: InputFrame, startup: int, guard: bool = false) -> void:
    _tick(battle, first, _guard(1) if guard else null)
    if first.is_pressed(InputFrame.InputButton.SPECIAL):
        var release_frame := battle.frame_number + 1
        _tick(battle, null, InputFrame.new(release_frame, 0, 0, InputFrame.InputButton.GUARD, 0, 0) if guard else null)
    for _i in range(startup):
        var f := battle.frame_number + 1
        _tick(battle, null, InputFrame.new(f, 0, 0, InputFrame.InputButton.GUARD, 0, 0) if guard else null)

func _test_rush_damage_runtime() -> void:
    var light := _battle()
    _advance_attack_to_contact(light, InputFrame.with_light_press(1), 4)
    t.equal(light.fighter_b.combatant.hp, 4955, "Rush Light actual simulation deals 45")
    t.equal(light.fighter_a.meter.get_value(), 35, "Rush Light actual HIT gains +7")

    var heavy := _battle()
    _advance_attack_to_contact(heavy, InputFrame.with_heavy_press(1), 9)
    t.equal(heavy.fighter_b.combatant.hp, 4910, "Rush Heavy actual simulation deals 90")

    var low := _battle()
    _advance_attack_to_contact(low, InputFrame.with_light_press(1, 0, -1), 7)
    t.equal(low.fighter_b.combatant.hp, 4945, "Rush Low actual simulation deals 55")

    var special := _battle()
    _advance_attack_to_contact(special, InputFrame.with_special_press(1), 8)
    t.equal(special.fighter_b.combatant.hp, 4900, "Rush Special actual simulation deals 100")
    t.equal(special.fighter_a.meter.get_value(), 80, "Rush Special actual HIT gains +16")

    var blocked := _battle()
    _advance_attack_to_contact(blocked, InputFrame.with_special_press(1), 8, true)
    t.equal(blocked.fighter_b.combatant.hp, 5000, "Rush Special BLOCK causes no chip damage")
    t.equal(blocked.fighter_a.meter.get_value(), 35, "Rush Special actual BLOCK gains +7")

func _start_throw_active(fighter: Fighter) -> void:
    var move := fighter.move_registry.get_move(MoveIds.GROUND_THROW)
    t.that(fighter.move_runner.start_move(move), "Throw MoveRunner starts")
    fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
    fighter.state_machine.transition_to(FighterStateMachine.State.THROW)
    fighter.move_runner.move_frame = move.first_active_frame()

func _test_rush_throw_runtime_and_range() -> void:
    var actual := _battle(rush, generic, 50000, 57000)
    _advance_attack_to_contact(actual, InputFrame.with_heavy_press(1, 1), 5, true)
    t.equal(actual.fighter_b.combatant.hp, 4850, "Rush Forward+Heavy actual throw deals 150")
    t.equal(actual.fighter_a.meter.get_value(), 90, "Rush actual throw gains +18")
    t.equal(actual.fighter_b.state_machine.state, FighterStateMachine.State.THROWN, "Guard remains throwable by generic ThrowSystem")

    var generic_range := _battle(generic, rush, 50000, 63600)
    _start_throw_active(generic_range.fighter_a)
    var generic_contact := generic_range.throw_system.build_throw_contact(generic_range.fighter_a, generic_range.fighter_b)
    t.that(generic_contact == null, "Distance 136px is outside Generic throw geometry")

    var rush_range := _battle(rush, generic, 50000, 63600)
    _start_throw_active(rush_range.fighter_a)
    var rush_contact := rush_range.throw_system.build_throw_contact(rush_range.fighter_a, rush_range.fighter_b)
    t.that(rush_contact != null, "Same 136px distance is inside Rush throw geometry")

    var airborne := _battle(rush, generic, 50000, 57000)
    _start_throw_active(airborne.fighter_a)
    airborne.fighter_b.state_machine.transition_to(FighterStateMachine.State.JUMP)
    airborne.fighter_b.movement_motor.sim_position.y -= 100
    t.that(airborne.throw_system.build_throw_contact(airborne.fighter_a, airborne.fighter_b) == null, "Airborne target remains unthrowable")

    var attacking := _battle(rush, generic, 50000, 57000)
    _start_throw_active(attacking.fighter_a)
    attacking.fighter_b.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    t.that(attacking.throw_system.build_throw_contact(attacking.fighter_a, attacking.fighter_b) == null, "Attack state remains unthrowable")

func _runner_for(move_id: StringName, frame: int, hit: bool, block: bool) -> MoveRunner:
    var runner := MoveRunner.new()
    runner.configure(1)
    runner.start_move(registry.get_move(move_id))
    runner.move_frame = frame
    runner.connected_hit = hit
    runner.connected_block = block
    return runner

func _test_rush_cancel_graph() -> void:
    var light_hit := _runner_for(MoveIds.STAND_LIGHT, 5, true, false)
    t.that(light_hit.can_cancel_to(MoveIds.STAND_LIGHT), "Rush Light HIT F5 -> Light allowed")
    t.that(light_hit.can_cancel_to(MoveIds.STAND_HEAVY), "Rush Light HIT F5 -> Heavy allowed")
    var light_block := _runner_for(MoveIds.STAND_LIGHT, 5, false, true)
    t.that(light_block.can_cancel_to(MoveIds.STAND_HEAVY), "Rush Light BLOCK F5 -> Heavy allowed")
    t.that(not _runner_for(MoveIds.STAND_LIGHT, 5, false, false).can_cancel_to(MoveIds.STAND_HEAVY), "Rush Light WHIFF -> Heavy denied")

    for connected in [[true, false], [false, true]]:
        var low := _runner_for(MoveIds.CROUCH_LOW, 8, connected[0], connected[1])
        t.that(low.can_cancel_to(MoveIds.SPECIAL_NEUTRAL), "Rush Low HIT/BLOCK F8 -> Special allowed")
        var heavy := _runner_for(MoveIds.STAND_HEAVY, 10, connected[0], connected[1])
        t.that(heavy.can_cancel_to(MoveIds.SPECIAL_NEUTRAL), "Rush Heavy HIT/BLOCK F10 -> Special allowed")
    t.that(not _runner_for(MoveIds.CROUCH_LOW, 8, false, false).can_cancel_to(MoveIds.SPECIAL_NEUTRAL), "Rush Low WHIFF -> Special denied")
    t.that(not _runner_for(MoveIds.STAND_HEAVY, 10, false, false).can_cancel_to(MoveIds.SPECIAL_NEUTRAL), "Rush Heavy WHIFF -> Special denied")

    t.that(_runner_for(MoveIds.SPECIAL_NEUTRAL, 9, true, false).can_cancel_to(MoveIds.ULTIMATE), "Rush Special HIT F9 -> Ultimate allowed by cancel data")
    t.that(not _runner_for(MoveIds.SPECIAL_NEUTRAL, 9, false, true).can_cancel_to(MoveIds.ULTIMATE), "Rush Special BLOCK -> Ultimate denied")
    t.that(not _runner_for(MoveIds.SPECIAL_NEUTRAL, 9, false, false).can_cancel_to(MoveIds.ULTIMATE), "Rush Special WHIFF -> Ultimate denied")

    var generic_registry := MoveRegistry.new()
    generic_registry.configure(generic.move_set)
    var generic_low := MoveRunner.new()
    generic_low.configure(1)
    generic_low.start_move(generic_registry.get_move(MoveIds.CROUCH_LOW))
    generic_low.move_frame = 8
    generic_low.connected_hit = true
    t.that(not generic_low.can_cancel_to(MoveIds.SPECIAL_NEUTRAL), "Generic Crouch Low still has no Special cancel")

    var generic_light := MoveRunner.new()
    generic_light.configure(1)
    generic_light.start_move(generic_registry.get_move(MoveIds.STAND_LIGHT))
    generic_light.move_frame = 5
    generic_light.connected_hit = true
    t.that(not generic_light.can_cancel_to(MoveIds.STAND_HEAVY), "Generic Light F5 is outside its F6-12 window")
    t.that(light_hit.can_cancel_to(MoveIds.STAND_HEAVY), "Rush Light F5 is inside its distinct F5-11 window")

func _test_rush_ultimate_meter_gate() -> void:
    var denied := _battle()
    denied.fighter_a.meter.set_value(99)
    _tick(denied, InputFrame.with_ultimate_press(1))
    t.equal(denied.fighter_a.move_runner.current_move_id(), &"", "Rush Ultimate cannot start at 99 meter")
    t.equal(denied.fighter_a.meter.get_value(), 99, "Denied Ultimate does not spend meter")

    var allowed := _battle()
    allowed.fighter_a.meter.gain(100)
    _tick(allowed, InputFrame.with_ultimate_press(1))
    t.equal(allowed.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "Rush Ultimate starts at 100 meter")
    t.equal(allowed.fighter_a.meter.get_value(), 0, "Rush Ultimate spends 100 meter")
