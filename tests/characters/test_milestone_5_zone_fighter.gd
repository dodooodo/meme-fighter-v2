# Responsibility: M5 Zone Fighter data, movement, MoveRunner timelines, meter gate, and cancel graph regression.
class_name Milestone5ZoneFighterTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var registry: MoveRegistry

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    registry = MoveRegistry.new()
    t.that(registry.configure(zone.move_set), "Zone MoveSet configures through generic MoveRegistry")
    _test_character_and_movement_data()
    _test_move_timelines_and_payloads()
    _test_zone_movement_runtime()
    _test_zone_normals_and_throw_runtime()
    _test_cancel_graph()
    _test_ultimate_meter_gate_runtime()
    print("\nM5 Zone Fighter tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_character_and_movement_data() -> void:
    t.equal(zone.id, &"zone_fighter", "Zone stable CharacterData.id")
    t.equal(zone.max_hp, 5000, "Zone HP follows current roster-wide tuning")
    t.equal(zone.walk_forward_units_per_tick, 270, "Zone forward walk")
    t.equal(zone.walk_back_units_per_tick, 250, "Zone back walk")
    t.equal(zone.jump_velocity_y_units_per_tick, -1450, "Zone jump velocity")
    t.equal(zone.gravity_y_units_per_tick2, 75, "Zone gravity")
    t.equal(zone.max_fall_speed_y_units_per_tick, 1750, "Zone max fall")
    t.equal(zone.air_forward_units_per_tick, 220, "Zone air forward")
    t.equal(zone.air_back_units_per_tick, 230, "Zone air back")
    t.equal(zone.landing_recovery_frames, 3, "Zone landing recovery")
    t.equal(zone.dash_move_frames, 8, "Zone dash movement frames")
    t.equal(zone.dash_speed_units_per_tick, 820, "Zone dash speed")
    t.equal(zone.dash_recovery_frames, 5, "Zone dash recovery")
    t.equal(zone.backstep_move_frames, 7, "Zone backstep movement frames")
    t.equal(zone.backstep_speed_units_per_tick, 900, "Zone backstep speed")
    t.equal(zone.backstep_recovery_frames, 5, "Zone backstep recovery")

func _assert_timeline(id: StringName, startup: int, active: int, recovery: int) -> void:
    var runner := MoveRunner.new()
    runner.configure(1)
    var move := registry.get_move(id)
    t.that(runner.start_move(move), "%s starts through generic MoveRunner" % String(id))
    var s := 0
    var a := 0
    var r := 0
    while runner.is_running():
        match runner.phase():
            &"STARTUP": s += 1
            &"ACTIVE": a += 1
            &"RECOVERY": r += 1
        runner.finalize_tick(false)
    t.equal(s, startup, "%s startup exact" % String(id))
    t.equal(a, active, "%s active exact" % String(id))
    t.equal(r, recovery, "%s recovery exact" % String(id))

func _test_move_timelines_and_payloads() -> void:
    var expected := {
        MoveIds.STAND_LIGHT: [6, 3, 11, 48, 13, 9, 3, 3, MoveData.HitLevel.MID, 560, 0, 7, 3],
        MoveIds.STAND_HEAVY: [13, 4, 22, 100, 19, 13, 6, 6, MoveData.HitLevel.MID, 1000, 0, 12, 6],
        MoveIds.CROUCH_LOW: [9, 3, 17, 58, 15, 11, 4, 4, MoveData.HitLevel.LOW, 620, 0, 9, 4],
        MoveIds.AIR_ATTACK: [7, 4, 13, 68, 14, 10, 4, 4, MoveData.HitLevel.HIGH, 680, -320, 9, 4],
    }
    for id in expected.keys():
        var e: Array = expected[id]
        _assert_timeline(id, e[0], e[1], e[2])
        var move := registry.get_move(id)
        t.equal(move.damage, e[3], "%s damage" % String(id))
        t.equal(move.hitstun_frames, e[4], "%s hitstun" % String(id))
        t.equal(move.blockstun_frames, e[5], "%s blockstun" % String(id))
        t.equal(move.hitstop_attacker, e[6], "%s attacker hitstop" % String(id))
        t.equal(move.hitstop_defender, e[7], "%s defender hitstop" % String(id))
        t.equal(move.hit_level, e[8], "%s hit level" % String(id))
        t.equal(move.knockback_x_units, e[9], "%s knockback X" % String(id))
        t.equal(move.knockback_y_units, e[10], "%s knockback Y" % String(id))
        t.equal(move.meter_gain_on_hit, e[11], "%s HIT meter" % String(id))
        t.equal(move.meter_gain_on_block, e[12], "%s BLOCK meter" % String(id))
    _assert_timeline(MoveIds.GROUND_THROW, 6, 2, 20)
    var throw_move := registry.get_move(MoveIds.GROUND_THROW)
    t.equal(throw_move.damage, 110, "Zone Throw damage")
    t.equal(throw_move.throw_hold_frames, 10, "Zone Throw THROWN duration")
    t.equal(throw_move.knockdown_frames, 28, "Zone Throw knockdown")
    t.equal(throw_move.meter_gain_on_throw, 12, "Zone Throw meter")
    t.that(throw_move.hitbox == null and throw_move.throw_box != null, "Zone Throw remains throw_box only")
    _assert_timeline(MoveIds.SPECIAL_NEUTRAL, 14, 1, 20)
    var special := registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    t.equal(special.damage, 0, "Zone Special body damage zero")
    t.equal(special.total_frames() + 1, 36, "Zone Special is actionable on F36")
    t.that(special.hitbox == null, "Zone Special has no body hitbox")
    _assert_timeline(MoveIds.ULTIMATE, 18, 1, 30)
    var ultimate := registry.get_move(MoveIds.ULTIMATE)
    t.equal(ultimate.damage, 0, "Zone Ultimate body damage zero")
    t.equal(ultimate.total_frames() + 1, 50, "Zone Ultimate is actionable on F50")
    t.equal(ultimate.meter_cost, 100, "Zone Ultimate cost 100")
    t.that(ultimate.hitbox == null, "Zone Ultimate has no body hitbox")

func _tick_battle(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _test_zone_movement_runtime() -> void:
    var walk := _battle()
    _tick_battle(walk, InputFrame.new(1, 1, 0, 0, 0, 0))
    t.equal(walk.fighter_a.movement_motor.sim_position.x, 30270, "Zone forward walk integrates +270 units in one tick")
    var dash := _battle()
    _tick_battle(dash, InputFrame.new(1, 1, 0, 0, 0, 0))
    _tick_battle(dash, InputFrame.neutral(2))
    _tick_battle(dash, InputFrame.new(3, 1, 0, 0, 0, 0))
    t.equal(dash.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "Zone uses unchanged double-tap parser for Dash")
    t.equal(dash.fighter_a.movement_motor.velocity_units.x, 820, "Zone Dash runtime reads 820 speed from CharacterData")

func _advance_attack_to_contact(battle: BattleSimulation, first: InputFrame, startup: int, guard: bool = false) -> void:
    var guard_bit := InputFrame.InputButton.GUARD
    _tick_battle(battle, first, InputFrame.new(1, 0, 0, guard_bit, guard_bit, 0) if guard else null)
    for _i in range(startup):
        var f := battle.frame_number + 1
        _tick_battle(battle, null, InputFrame.new(f, 0, 0, guard_bit, 0, 0) if guard else null)

func _test_zone_normals_and_throw_runtime() -> void:
    var close_generic := load("res://data/characters/generic_fighter.tres") as CharacterData
    var light := BattleSimulation.new()
    light.configure(zone, close_generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS))
    _advance_attack_to_contact(light, InputFrame.with_light_press(1), 6)
    t.equal(light.fighter_b.combatant.hp, 4952, "Zone Light actual simulation deals 48")
    t.equal(light.fighter_a.meter.get_value(), 7, "Zone Light actual HIT gives +7 meter")
    var heavy := BattleSimulation.new()
    heavy.configure(zone, close_generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS))
    _advance_attack_to_contact(heavy, InputFrame.with_heavy_press(1), 13)
    t.equal(heavy.fighter_b.combatant.hp, 4900, "Zone Heavy actual simulation deals 100")
    var low := BattleSimulation.new()
    low.configure(zone, close_generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS))
    _advance_attack_to_contact(low, InputFrame.with_light_press(1, 0, -1), 9)
    t.equal(low.fighter_b.combatant.hp, 4942, "Zone Low actual simulation deals 58")
    var throw_battle := BattleSimulation.new()
    throw_battle.configure(zone, close_generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS))
    _advance_attack_to_contact(throw_battle, InputFrame.with_heavy_press(1, 1), 6, true)
    for _i in range(6):
        _tick_battle(throw_battle, null, InputFrame.new(throw_battle.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD, 0, 0))
    t.equal(throw_battle.fighter_b.combatant.hp, 4890, "Zone Forward+Heavy actual throw deals 110")
    t.equal(throw_battle.fighter_a.meter.get_value(), 12, "Zone actual Throw gives +12 meter")

func _test_cancel_graph() -> void:
    var light := registry.get_move(MoveIds.STAND_LIGHT)
    var heavy := registry.get_move(MoveIds.STAND_HEAVY)
    t.equal(light.cancel_windows.size(), 1, "Zone Light has one cancel window")
    t.equal(light.cancel_windows[0].start_frame, 7, "Zone Light cancel starts F7")
    t.equal(light.cancel_windows[0].end_frame, 13, "Zone Light cancel ends F13")
    t.that(light.cancel_windows[0].allows_target(MoveIds.STAND_HEAVY), "Zone Light -> Heavy")
    t.that(light.cancel_windows[0].allows_target(MoveIds.SPECIAL_NEUTRAL), "Zone Light -> Special")
    t.equal(heavy.cancel_windows[0].start_frame, 14, "Zone Heavy cancel starts F14")
    t.equal(heavy.cancel_windows[0].end_frame, 21, "Zone Heavy cancel ends F21")
    t.that(heavy.cancel_windows[0].allows_target(MoveIds.SPECIAL_NEUTRAL), "Zone Heavy -> Special")
    for id in [MoveIds.CROUCH_LOW, MoveIds.AIR_ATTACK, MoveIds.GROUND_THROW, MoveIds.SPECIAL_NEUTRAL, MoveIds.ULTIMATE]:
        t.that(registry.get_move(id).cancel_windows.is_empty(), "%s has no cancel windows" % String(id))

func _battle() -> BattleSimulation:
    var generic := load("res://data/characters/generic_fighter.tres") as CharacterData
    var battle := BattleSimulation.new()
    battle.configure(zone, generic, null, null, Vector2i(30000, BattleSimulation.GROUND_Y_UNITS), Vector2i(100000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _test_ultimate_meter_gate_runtime() -> void:
    var denied := _battle()
    denied.fighter_a.meter.set_value(99)
    denied.simulate_frame(InputFrame.with_ultimate_press(1), InputFrame.neutral(1))
    t.that(denied.fighter_a.move_runner.current_move_id() != MoveIds.ULTIMATE, "Zone Ultimate cannot start at 99 meter")
    t.equal(denied.fighter_a.meter.get_value(), 99, "Denied Ultimate does not spend meter")
    var allowed := _battle()
    allowed.fighter_a.meter.set_value(100)
    allowed.simulate_frame(InputFrame.with_ultimate_press(1), InputFrame.neutral(1))
    t.equal(allowed.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "Zone Ultimate starts at 100 meter")
    t.equal(allowed.fighter_a.meter.get_value(), 0, "Zone Ultimate spends 100 immediately")
