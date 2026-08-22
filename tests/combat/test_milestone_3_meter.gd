# Responsibility: M3 deterministic MeterComponent and combat-outcome meter regression suite.
class_name Milestone3MeterTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_meter_component_contract()
    _test_move_meter_data()
    _test_normal_hit_block_meter_gain()
    _test_air_throw_special_meter_gain()
    _test_duplicate_contact_meter_gain_once()
    _test_same_frame_trade_awards_both()
    _test_ultimate_awards_no_meter()
    print("\nM3 Meter tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 50000, p2_x: int = 58000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(character, character, null, null, Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS), Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _guard(frame: int, down: bool = false, pressed: bool = false) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, -1 if down else 0, bit, bit if pressed else 0, 0)

func _advance_to_first_contact(battle: BattleSimulation, first_input: InputFrame, startup_frames: int, defender_guarding: bool = false) -> void:
    var f := battle.frame_number + 1
    _tick(battle, first_input, _guard(f, false, true) if defender_guarding else null)
    if first_input.is_pressed(InputFrame.InputButton.SPECIAL):
        f = battle.frame_number + 1
        _tick(battle, null, _guard(f, false, false) if defender_guarding else null) # release tap -> Lv1 MoveRunner start
    for _i in range(startup_frames):
        f = battle.frame_number + 1
        _tick(battle, null, _guard(f, false, false) if defender_guarding else null)

func _test_meter_component_contract() -> void:
    var meter := MeterComponent.new()
    t.equal(meter.get_value(), 0, "Meter starts at 0")
    meter.gain(73)
    t.equal(meter.get_value(), 73, "Meter gain uses integer value")
    meter.gain(50)
    t.equal(meter.get_value(), 100, "Meter gain clamps to 100")
    meter.gain(-20)
    t.equal(meter.get_value(), 100, "Negative meter gain is ignored")
    t.that(meter.can_spend(100), "Meter can_spend succeeds at exact value")
    t.that(meter.spend(100), "Meter spend succeeds when affordable")
    t.equal(meter.get_value(), 0, "Successful spend subtracts cost")
    t.that(not meter.spend(1), "Meter spend fails when unaffordable")
    t.equal(meter.get_value(), 0, "Failed spend does not mutate meter")
    t.that(not meter.spend(-1), "Negative spend is rejected")
    t.that(meter.spend(0), "Cost 0 succeeds")
    meter.gain(44)
    meter.reset()
    t.equal(meter.get_value(), 0, "Meter reset returns to 0")

func _test_move_meter_data() -> void:
    var registry := MoveRegistry.new()
    t.that(registry.configure(character.move_set), "M3 MoveSet configures for meter data tests")
    var expected := {
        MoveIds.STAND_LIGHT: [8, 4, 0],
        MoveIds.STAND_HEAVY: [12, 6, 0],
        MoveIds.CROUCH_LOW: [10, 5, 0],
        MoveIds.AIR_ATTACK: [10, 5, 0],
        MoveIds.GROUND_THROW: [0, 0, 15],
        MoveIds.SPECIAL_NEUTRAL: [18, 8, 0],
        MoveIds.ULTIMATE: [0, 0, 0],
    }
    for move_id in expected.keys():
        var move := registry.get_move(move_id)
        var values: Array = expected[move_id]
        t.that(move != null, "%s exists in MoveRegistry" % String(move_id))
        t.equal(move.meter_gain_on_hit, values[0], "%s hit meter gain is data-defined" % String(move_id))
        t.equal(move.meter_gain_on_block, values[1], "%s block meter gain is data-defined" % String(move_id))
        t.equal(move.meter_gain_on_throw, values[2], "%s throw meter gain is data-defined" % String(move_id))
    t.equal(registry.get_move(MoveIds.ULTIMATE).meter_cost, 100, "Ultimate meter cost is 100")
    t.equal(registry.get_move(MoveIds.SPECIAL_NEUTRAL).meter_cost, 0, "Special meter cost is 0")

func _test_normal_hit_block_meter_gain() -> void:
    var light_hit := _battle()
    _advance_to_first_contact(light_hit, InputFrame.with_light_press(1), 5)
    t.equal(light_hit.fighter_a.meter.get_value(), 8, "Stand Light HIT gains +8")

    var light_block := _battle()
    _advance_to_first_contact(light_block, InputFrame.with_light_press(1), 5, true)
    t.equal(light_block.fighter_a.meter.get_value(), 4, "Stand Light BLOCK gains +4")

    var heavy_hit := _battle()
    _advance_to_first_contact(heavy_hit, InputFrame.with_heavy_press(1), 11)
    t.equal(heavy_hit.fighter_a.meter.get_value(), 12, "Stand Heavy HIT gains +12")

    var low_hit := _battle()
    _advance_to_first_contact(low_hit, InputFrame.with_light_press(1, 0, -1), 8)
    t.equal(low_hit.fighter_a.meter.get_value(), 10, "Crouch Low HIT gains +10")

func _test_air_throw_special_meter_gain() -> void:
    var air := _battle()
    _tick(air, InputFrame.new(1, 0, 1, 0, 0, 0))
    _tick(air, InputFrame.with_light_press(2))
    for _i in range(6):
        _tick(air)
    t.equal(air.fighter_a.meter.get_value(), 10, "Air Attack HIT gains +10")

    var throw_battle := _battle()
    _advance_to_first_contact(throw_battle, InputFrame.with_heavy_press(1, 1), 5, true)
    t.equal(throw_battle.fighter_a.meter.get_value(), 15, "Ground Throw THROW result gains +15")

    var special_hit := _battle()
    _advance_to_first_contact(special_hit, InputFrame.with_special_press(1), 10)
    t.equal(special_hit.fighter_a.meter.get_value(), 18, "Special HIT gains +18")

    var special_block := _battle()
    _advance_to_first_contact(special_block, InputFrame.with_special_press(1), 10, true)
    t.equal(special_block.fighter_a.meter.get_value(), 8, "Special BLOCK gains +8")

func _test_duplicate_contact_meter_gain_once() -> void:
    var battle := _battle()
    _advance_to_first_contact(battle, InputFrame.with_special_press(1), 10)
    t.equal(battle.fighter_a.meter.get_value(), 18, "Special first active contact grants meter once")
    battle.fighter_a.combatant.hitstop_remaining = 0
    battle.fighter_b.combatant.hitstop_remaining = 0
    var hp_after := battle.fighter_b.combatant.hp
    for _i in range(3):
        _tick(battle)
    t.equal(battle.fighter_a.meter.get_value(), 18, "Same AttackInstance active overlap cannot grant meter repeatedly")
    t.equal(battle.fighter_b.combatant.hp, hp_after, "Duplicate-contact meter protection matches duplicate damage protection")

func _test_same_frame_trade_awards_both() -> void:
    var battle := _battle()
    _tick(battle, InputFrame.with_light_press(1), InputFrame.with_light_press(1))
    for _i in range(5):
        _tick(battle)
    t.equal(battle.fighter_a.meter.get_value(), 8, "Same-frame trade awards P1 meter")
    t.equal(battle.fighter_b.meter.get_value(), 8, "Same-frame trade awards P2 meter")

func _test_ultimate_awards_no_meter() -> void:
    var battle := _battle()
    battle.fighter_a.meter.gain(100)
    _advance_to_first_contact(battle, InputFrame.with_ultimate_press(1), 14)
    t.equal(battle.fighter_a.meter.get_value(), 0, "Ultimate spends 100 and awards no hit meter")
