# Responsibility: M3 Meter/Cancel/Ultimate/AttackInstance snapshot-restore-hash regression suite.
class_name Milestone3SnapshotTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_meter_capture_restore_hash()
    _test_cancel_connection_snapshot_replay()
    _test_ultimate_spend_mid_startup_roundtrip()
    _test_duplicate_meter_contact_restore()
    _test_cancel_attack_instance_roundtrip()
    print("\nM3 Snapshot tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(close: bool = true) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        character,
        character,
        null,
        null,
        Vector2i(50000, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(58000 if close else 100000, BattleSimulation.GROUND_Y_UNITS)
    )
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _test_meter_capture_restore_hash() -> void:
    var battle := _battle(false)
    battle.fighter_a.meter.set_value(73)
    var snapshot := battle.capture_state()
    var hash_73 := battle.state_signature()
    t.equal(snapshot.fighter_a.meter_value, 73, "Snapshot captures exact P1 meter integer")
    battle.fighter_a.meter.gain(27)
    t.equal(battle.fighter_a.meter.get_value(), 100, "Setup mutates meter after capture")
    t.that(battle.state_signature() != hash_73, "Meter participates in canonical battle hash")
    t.that(battle.restore_state(snapshot), "Meter snapshot restores")
    t.equal(battle.fighter_a.meter.get_value(), 73, "Restore returns meter exactly to 73")
    t.equal(battle.state_signature(), hash_73, "Restore returns canonical hash including meter")

func _test_cancel_connection_snapshot_replay() -> void:
    var battle := _battle(true)
    _tick(battle, InputFrame.with_heavy_press(1))
    for _i in range(11):
        _tick(battle)
    t.that(battle.fighter_a.move_runner.connected_hit, "Heavy setup has resolved HIT connection")
    for _i in range(5):
        _tick(battle)
    t.equal(battle.fighter_a.combatant.hitstop_remaining, 0, "Heavy hitstop has ended before cancel snapshot")
    t.equal(battle.fighter_a.move_runner.move_frame, 12, "Heavy remains on frozen F12 cancel frame")
    var snapshot := battle.capture_state()
    t.that(snapshot.fighter_a.move_connected_hit and not snapshot.fighter_a.move_connected_block, "Snapshot captures current MoveRunner HIT/BLOCK connection facts")
    var next_frame := battle.frame_number + 1
    var cancel_input := InputFrame.with_special_press(next_frame)
    _tick(battle, cancel_input)
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CHARGE, "Heavy HIT snapshot path cancels into committed Special CHARGE")
    t.that(not battle.fighter_a.move_runner.is_running(), "Cancel into CHARGE stops the old Heavy AttackInstance")
    _tick(battle)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL, "Tap-release after Heavy cancel starts Lv1 Special")
    var signature_a := battle.state_signature()
    t.that(battle.restore_state(snapshot), "Heavy cancel-ready snapshot restores")
    t.that(battle.fighter_a.move_runner.connected_hit, "Restore preserves HIT connection needed for cancel legality")
    _tick(battle, cancel_input)
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CHARGE, "Restored same input reproduces Heavy -> CHARGE cancel")
    _tick(battle)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL, "Restored tap-release reproduces Lv1 Special")
    t.equal(battle.state_signature(), signature_a, "Cancel-ready restore/replay produces identical hash")

func _test_ultimate_spend_mid_startup_roundtrip() -> void:
    var battle := _battle(false)
    battle.fighter_a.meter.gain(100)
    _tick(battle, InputFrame.with_ultimate_press(1))
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "Ultimate setup starts")
    t.equal(battle.fighter_a.meter.get_value(), 0, "Ultimate cost is already spent before mid-startup snapshot")
    var snapshot := battle.capture_state()
    t.equal(snapshot.fighter_a.meter_value, 0, "Mid-Ultimate snapshot stores spent meter as 0")
    for _i in range(8):
        _tick(battle)
    var signature_a := battle.state_signature()
    t.that(battle.restore_state(snapshot), "Mid-Ultimate snapshot restores")
    t.equal(battle.fighter_a.meter.get_value(), 0, "Restore does not refund Ultimate cost")
    for _i in range(8):
        _tick(battle)
    t.equal(battle.state_signature(), signature_a, "Ultimate mid-startup restore/replay hash matches")

func _test_duplicate_meter_contact_restore() -> void:
    var battle := _battle(true)
    _tick(battle, InputFrame.with_light_press(1))
    for _i in range(5):
        _tick(battle)
    t.equal(battle.fighter_a.meter.get_value(), 40, "Light setup already awarded tuned meter")
    t.equal(battle.fighter_b.combatant.hp, 4950, "Light setup already applied damage once")
    battle.fighter_a.combatant.hitstop_remaining = 0
    battle.fighter_b.combatant.hitstop_remaining = 0
    var snapshot := battle.capture_state()
    t.that(snapshot.fighter_a.contacted_defender_ids.has(2), "Snapshot contains already-contacted defender identity")
    var hp_before := battle.fighter_b.combatant.hp
    var meter_before := battle.fighter_a.meter.get_value()
    _tick(battle)
    var signature_a := battle.state_signature()
    t.equal(battle.fighter_b.combatant.hp, hp_before, "Next active overlap after snapshot does not damage again")
    t.equal(battle.fighter_a.meter.get_value(), meter_before, "Next active overlap after snapshot does not award meter again")
    t.that(battle.restore_state(snapshot), "Duplicate-meter snapshot restores")
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, hp_before, "Restored contact registry still prevents duplicate damage")
    t.equal(battle.fighter_a.meter.get_value(), meter_before, "Restored contact registry still prevents duplicate meter")
    t.equal(battle.state_signature(), signature_a, "Duplicate contact restore/replay hash matches")

func _test_cancel_attack_instance_roundtrip() -> void:
    var battle := _battle(true)
    _tick(battle, InputFrame.with_light_press(1))
    for _i in range(5):
        _tick(battle)
    var old_instance := battle.fighter_a.move_runner.attack_instance_id
    var f := battle.frame_number + 1
    _tick(battle, InputFrame.with_heavy_press(f))
    for _i in range(3):
        _tick(battle)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Light HIT -> Heavy cancel setup completes")
    var new_instance := battle.fighter_a.move_runner.attack_instance_id
    t.that(new_instance != old_instance, "Cancel target has new AttackInstance before snapshot")
    t.equal(battle.fighter_a.hitbox_owner.tracked_attack_instance_id(), new_instance, "Contact registry tracks cancel target instance before snapshot")
    var snapshot := battle.capture_state()
    var serial := battle.fighter_a.move_runner.instance_serial()
    _tick(battle)
    var signature_a := battle.state_signature()
    t.that(battle.restore_state(snapshot), "Post-cancel AttackInstance snapshot restores")
    t.equal(battle.fighter_a.move_runner.attack_instance_id, new_instance, "Restore preserves cancel target AttackInstanceID")
    t.equal(battle.fighter_a.move_runner.instance_serial(), serial, "Restore preserves deterministic next AttackInstance serial state")
    t.equal(battle.fighter_a.hitbox_owner.tracked_attack_instance_id(), new_instance, "Restore preserves cancel target contact-registry identity")
    _tick(battle)
    t.equal(battle.state_signature(), signature_a, "Post-cancel AttackInstance restore/replay hash matches")
