# Responsibility: M8B generic charge-special state/data/snapshot/cancel regression tests.
class_name M8ChargeSpecialTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData
var zone: CharacterData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    _test_shared_charge_configuration()
    _test_thresholds_and_no_auto_release()
    _test_charge_commitment_blocks_control()
    _test_charge_is_vulnerable_to_hit_and_throw()
    _test_round_reset_clears_charge()
    _test_charge_snapshot_restore_hash()
    _test_heavy_cancel_enters_charge()
    _test_release_special_can_data_cancel_to_ultimate()
    _test_zone_levels_use_projectile_system_data()
    print("\nM8B Charge Special tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(character_a: CharacterData = null, close: bool = false) -> BattleSimulation:
    var chosen := character_a if character_a != null else generic
    var battle := BattleSimulation.new()
    battle.configure(chosen, generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(58000 if close else 100000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _special_input(frame: int, held: bool, pressed: bool = false, released: bool = false, x: int = 0, y: int = 0, extra_held: int = 0, extra_pressed: int = 0) -> InputFrame:
    var special := InputFrame.InputButton.SPECIAL
    var held_bits := extra_held | (special if held else 0)
    var pressed_bits := extra_pressed | (special if pressed else 0)
    var released_bits := special if released else 0
    return InputFrame.new(frame, x, y, held_bits, pressed_bits, released_bits)

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _charge_and_release(held_frames: int, character: CharacterData = null) -> BattleSimulation:
    var battle := _battle(character)
    _tick(battle, _special_input(1, true, true))
    for f in range(2, held_frames + 1):
        _tick(battle, _special_input(f, true))
    _tick(battle, _special_input(held_frames + 1, false, false, true))
    return battle

func _test_shared_charge_configuration() -> void:
    for character in [generic, rush, zone]:
        var registry := MoveRegistry.new()
        t.that(registry.configure(character.move_set), "%s MoveRegistry configures with generic ChargeSpecialData" % String(character.id))
        var entry := registry.get_move(MoveIds.SPECIAL_NEUTRAL)
        t.that(entry != null and entry.charge_special_data != null, "%s SPECIAL_NEUTRAL owns typed charge configuration" % String(character.id))
        t.equal(entry.charge_special_data.level_2_threshold_frames, 24, "%s Lv2 threshold is 24F" % String(character.id))
        t.equal(entry.charge_special_data.level_3_threshold_frames, 54, "%s Lv3 threshold is 54F" % String(character.id))
        t.that(registry.has_move(MoveIds.SPECIAL_NEUTRAL_L2) and registry.has_move(MoveIds.SPECIAL_NEUTRAL_L3), "%s registry contains stable Lv2/Lv3 Move IDs" % String(character.id))

func _test_thresholds_and_no_auto_release() -> void:
    var l1 := _charge_and_release(23)
    t.equal(l1.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL, "23F release selects Lv1 canonical special")
    var l2_min := _charge_and_release(24)
    t.equal(l2_min.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL_L2, "24F release selects Lv2")
    var l2_max := _charge_and_release(53)
    t.equal(l2_max.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL_L2, "53F release remains Lv2")
    var l3 := _charge_and_release(54)
    t.equal(l3.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL_L3, "54F release selects Lv3")

    var hold := _battle()
    _tick(hold, _special_input(1, true, true))
    for f in range(2, 121):
        _tick(hold, _special_input(f, true))
    t.equal(hold.fighter_a.state_machine.state, FighterStateMachine.State.CHARGE, "Holding 120F remains CHARGE and never auto-releases")
    t.equal(hold.fighter_a.state_machine.charge_frames, 120, "Charge uses deterministic integer simulation-frame count")
    _tick(hold, _special_input(121, false, false, true))
    t.equal(hold.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL_L3, "Release after 120F starts Lv3")

func _test_charge_commitment_blocks_control() -> void:
    var battle := _battle()
    _tick(battle, _special_input(1, true, true))
    var start_x := battle.fighter_a.movement_motor.sim_position.x
    var prohibited := [
        _special_input(2, true, false, false, 1, 0),
        _special_input(3, true, false, false, 0, 1),
        _special_input(4, true, false, false, 0, 0, InputFrame.InputButton.GUARD, InputFrame.InputButton.GUARD),
        _special_input(5, true, false, false, 0, 0, InputFrame.InputButton.LIGHT, InputFrame.InputButton.LIGHT),
        _special_input(6, true, false, false, 0, 0, InputFrame.InputButton.HEAVY, InputFrame.InputButton.HEAVY),
        _special_input(7, true, false, false, 0, 0, InputFrame.InputButton.ULTIMATE, InputFrame.InputButton.ULTIMATE),
    ]
    for input in prohibited:
        _tick(battle, input)
        t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CHARGE, "CHARGE rejects movement/jump/guard/offense/ultimate while Special remains held")
        t.equal(battle.fighter_a.movement_motor.sim_position.x, start_x, "CHARGE horizontal root remains immobile")
        t.that(not battle.fighter_a.move_runner.is_running(), "CHARGE does not start attack before release")

func _test_charge_is_vulnerable_to_hit_and_throw() -> void:
    var hit := _battle(generic, true)
    _tick(hit, _special_input(1, true, true), InputFrame.with_light_press(1))
    for f in range(2, 9):
        _tick(hit, _special_input(f, true))
        if hit.fighter_a.combatant.hitstun_remaining > 0:
            break
    t.that(hit.fighter_a.combatant.hitstun_remaining > 0, "Charging fighter can be struck normally")
    t.that(hit.fighter_a.state_machine.state != FighterStateMachine.State.CHARGE, "HIT immediately clears CHARGE")
    t.equal(hit.fighter_a.state_machine.charge_frames, 0, "HIT clears charge frame state")

    var thrown := _battle(generic, true)
    _tick(thrown, _special_input(1, true, true), InputFrame.with_heavy_press(1, -1, 0))
    for f in range(2, 20):
        _tick(thrown, _special_input(f, true))
        if thrown.fighter_a.state_machine.state == FighterStateMachine.State.THROWN:
            break
    t.equal(thrown.fighter_a.state_machine.state, FighterStateMachine.State.THROWN, "Charging fighter remains throwable through Forward + Heavy pipeline")
    t.equal(thrown.fighter_a.state_machine.charge_frames, 0, "Throw clears charge state")

func _test_round_reset_clears_charge() -> void:
    var battle := _battle()
    _tick(battle, _special_input(1, true, true))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CHARGE, "Charge setup enters CHARGE")
    battle.reset_full_match()
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Full match reset clears CHARGE")
    t.equal(battle.fighter_a.state_machine.charge_frames, 0, "Reset clears charge frames")

func _test_charge_snapshot_restore_hash() -> void:
    var battle := _battle()
    _tick(battle, _special_input(1, true, true))
    for f in range(2, 31):
        _tick(battle, _special_input(f, true))
    var snapshot := battle.capture_state()
    t.equal(snapshot.version, 8, "M8 gameplay snapshot schema is v8")
    t.equal(snapshot.fighter_a.charge_frames, 30, "Snapshot captures authoritative charge frame count")
    var replay_inputs: Array[InputFrame] = []
    for f in range(31, 41):
        replay_inputs.append(_special_input(f, true))
    for input in replay_inputs:
        _tick(battle, input)
    var signature := battle.state_signature()
    t.that(battle.restore_state(snapshot), "Charging snapshot restores")
    for input in replay_inputs:
        _tick(battle, input)
    t.equal(battle.state_signature(), signature, "Restore + identical held inputs reproduces exact charge hash")

func _test_heavy_cancel_enters_charge() -> void:
    var battle := _battle()
    var heavy := battle.fighter_a.move_registry.get_move(MoveIds.STAND_HEAVY)
    t.that(battle.fighter_a.move_runner.start_move(heavy), "Heavy cancel test starts authoritative MoveRunner move")
    battle.fighter_a.hitbox_owner.begin_attack_instance(battle.fighter_a.move_runner.attack_instance_id)
    battle.fighter_a.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    battle.fighter_a.move_runner.move_frame = 12
    battle.fighter_a.move_runner.connected_hit = true
    _tick(battle, _special_input(1, true, true))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CHARGE, "Heavy HIT cancel window accepts Special and enters CHARGE")
    t.that(not battle.fighter_a.move_runner.is_running(), "Cancel into CHARGE immediately stops old Heavy AttackInstance")
    t.equal(battle.fighter_a.state_machine.charge_entry_move_id, MoveIds.SPECIAL_NEUTRAL, "Cancel charge keeps stable canonical entry Move ID")

func _test_release_special_can_data_cancel_to_ultimate() -> void:
    var battle := _battle()
    battle.fighter_a.meter.gain(100)
    var special := battle.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    t.that(battle.fighter_a.move_runner.start_move(special), "Special->Ultimate test starts released Lv1 move")
    battle.fighter_a.hitbox_owner.begin_attack_instance(battle.fighter_a.move_runner.attack_instance_id)
    battle.fighter_a.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    battle.fighter_a.move_runner.move_frame = 11
    battle.fighter_a.move_runner.connected_hit = true
    _tick(battle, InputFrame.with_ultimate_press(1))
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "Released Special uses MoveData cancel window to enter Ultimate")
    t.equal(battle.fighter_a.meter.get_value(), 0, "Ultimate cancel still pays target MoveData meter cost")

func _test_zone_levels_use_projectile_system_data() -> void:
    var registry := MoveRegistry.new()
    t.that(registry.configure(zone.move_set), "Zone registry configures three generic charge release moves")
    for move_id in [MoveIds.SPECIAL_NEUTRAL, MoveIds.SPECIAL_NEUTRAL_L2, MoveIds.SPECIAL_NEUTRAL_L3]:
        var move := registry.get_move(move_id)
        t.equal(move.projectile_spawns.size(), 1, "%s owns exactly one generic ProjectileSpawnData descriptor" % String(move_id))
        t.that(move.hitbox == null, "%s remains body-hitbox-free projectile special" % String(move_id))
