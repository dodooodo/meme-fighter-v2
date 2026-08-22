# Responsibility: M4 snapshot character-identity compatibility, per-fighter MoveRegistry rehydration, and hash regression suite.
class_name Milestone4CharacterSnapshotTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    _test_identity_capture_and_same_character_restore()
    _test_cross_character_restore_rejected()
    _test_same_move_id_rehydrates_from_correct_registry()
    _test_character_identity_changes_hash()
    _test_rush_mid_move_restore_replay_cases()
    _test_rush_duplicate_contact_snapshot()
    print("\nM4 Character Snapshot tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData = null, b: CharacterData = null, ax: int = 50000, bx: int = 57000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a if a != null else generic, b if b != null else rush, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _test_identity_capture_and_same_character_restore() -> void:
    var battle := _battle(generic, rush)
    var snapshot := battle.capture_state()
    t.equal(snapshot.version, BattleStateSnapshot.VERSION, "Character-identity snapshot test follows current same-build schema")
    t.equal(snapshot.fighter_a.character_id, &"generic_fighter", "Generic snapshot captures immutable character identity")
    t.equal(snapshot.fighter_b.character_id, &"rush_grappler", "Rush snapshot captures immutable character identity")
    _tick(battle, InputFrame.with_light_press(1), InputFrame.with_light_press(1))
    t.that(battle.restore_state(snapshot), "Generic/Rush snapshot restores into same participants")
    t.equal(battle.fighter_a.data.id, &"generic_fighter", "Restore does not swap Generic CharacterData")
    t.equal(battle.fighter_b.data.id, &"rush_grappler", "Restore does not swap Rush CharacterData")

func _test_cross_character_restore_rejected() -> void:
    var source_generic := _battle(generic, rush)
    var generic_snapshot := source_generic.capture_state().fighter_a
    var rush_target := _battle(rush, generic)
    t.that(not FighterSnapshotCodec.restore(rush_target.fighter_a, generic_snapshot), "Generic fighter snapshot -> Rush fighter is rejected")

    var source_rush := _battle(generic, rush)
    var rush_snapshot := source_rush.capture_state().fighter_b
    var generic_target := _battle(generic, rush)
    # Match fighter slot ID=2 while changing only character configuration.
    var generic_as_p2 := _battle(rush, generic)
    t.that(not FighterSnapshotCodec.restore(generic_as_p2.fighter_b, rush_snapshot), "Rush fighter snapshot -> Generic fighter is rejected")
    t.equal(generic_target.fighter_a.data.id, &"generic_fighter", "Cross-character rejection does not auto-swap CharacterData")

func _test_same_move_id_rehydrates_from_correct_registry() -> void:
    var battle := _battle(generic, rush, 30000, 90000)
    var generic_light := battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT)
    var rush_light := battle.fighter_b.move_registry.get_move(MoveIds.STAND_LIGHT)
    battle.fighter_a.move_runner.start_move(generic_light)
    battle.fighter_a.hitbox_owner.begin_attack_instance(battle.fighter_a.move_runner.attack_instance_id)
    battle.fighter_b.move_runner.start_move(rush_light)
    battle.fighter_b.hitbox_owner.begin_attack_instance(battle.fighter_b.move_runner.attack_instance_id)
    var snapshot := battle.capture_state()
    battle.fighter_a.move_runner.interrupt()
    battle.fighter_b.move_runner.interrupt()
    t.that(battle.restore_state(snapshot), "Snapshot with same canonical Stand Light on both fighters restores")
    t.equal(battle.fighter_a.move_runner.current_move, generic_light, "Generic stand_light rehydrates through Generic registry")
    t.equal(battle.fighter_b.move_runner.current_move, rush_light, "Rush stand_light rehydrates through Rush registry")
    t.equal(battle.fighter_a.move_runner.current_move.damage, 50, "Generic rehydrated Light damage remains 50")
    t.equal(battle.fighter_b.move_runner.current_move.damage, 45, "Rush rehydrated Light damage remains 45")

func _test_character_identity_changes_hash() -> void:
    var generic_state := _battle(generic, generic, 30000, 90000).capture_state()
    var rush_state := _battle(rush, generic, 30000, 90000).capture_state()
    # All fresh mutable fields and slot IDs are equal; P1 immutable CharacterData identity differs.
    t.that(BattleStateHasher.hash_snapshot(generic_state) != BattleStateHasher.hash_snapshot(rush_state), "Character ID participates in canonical gameplay state hash")
    t.that(BattleStateHasher.canonical_string(generic_state).contains("character=generic_fighter"), "Hasher uses stable textual Generic identity")
    t.that(BattleStateHasher.canonical_string(rush_state).contains("character=rush_grappler"), "Hasher uses stable textual Rush identity")

func _start_direct_move(battle: BattleSimulation, move_id: StringName, frame: int, connected_hit: bool = false, connected_block: bool = false) -> void:
    var fighter := battle.fighter_b
    var move := fighter.move_registry.get_move(move_id)
    fighter.move_runner.start_move(move)
    fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
    fighter.move_runner.move_frame = frame
    fighter.move_runner.connected_hit = connected_hit
    fighter.move_runner.connected_block = connected_block
    fighter.state_machine.transition_to(FighterStateMachine.State.THROW if move_id == MoveIds.GROUND_THROW else FighterStateMachine.State.GROUND_ATTACK)

func _assert_restore_next(battle: BattleSimulation, label: String) -> void:
    var snapshot := battle.capture_state()
    var before := battle.state_signature()
    var next_frame := battle.frame_number + 1
    battle.simulate_frame(InputFrame.neutral(next_frame), InputFrame.neutral(next_frame))
    var after := battle.state_signature()
    t.that(battle.restore_state(snapshot), "%s snapshot restores" % label)
    t.equal(battle.state_signature(), before, "%s restores exact canonical hash" % label)
    battle.simulate_frame(InputFrame.neutral(next_frame), InputFrame.neutral(next_frame))
    t.equal(battle.state_signature(), after, "%s restore/replay hash equality" % label)

func _test_rush_mid_move_restore_replay_cases() -> void:
    var light := _battle(generic, rush, 30000, 90000)
    _start_direct_move(light, MoveIds.STAND_LIGHT, 5)
    _assert_restore_next(light, "Rush Light Active")

    var throw_active := _battle(generic, rush, 30000, 90000)
    _start_direct_move(throw_active, MoveIds.GROUND_THROW, 6)
    _assert_restore_next(throw_active, "Rush Throw Active")

    var special_recovery := _battle(generic, rush, 30000, 90000)
    _start_direct_move(special_recovery, MoveIds.SPECIAL_NEUTRAL, 13)
    _assert_restore_next(special_recovery, "Rush Special Recovery")

    var ultimate_startup := _battle(generic, rush, 30000, 90000)
    _start_direct_move(ultimate_startup, MoveIds.ULTIMATE, 6)
    _assert_restore_next(ultimate_startup, "Rush Ultimate mid-startup")

    var low_cancel_ready := _battle(generic, rush, 30000, 90000)
    _start_direct_move(low_cancel_ready, MoveIds.CROUCH_LOW, 8, true, false)
    t.that(low_cancel_ready.fighter_b.move_runner.can_cancel_to(MoveIds.SPECIAL_NEUTRAL), "Rush Low snapshot setup is cancel-ready")
    _assert_restore_next(low_cancel_ready, "Rush Low cancel-ready")

func _test_rush_duplicate_contact_snapshot() -> void:
    var battle := _battle(rush, generic, 50000, 57000)
    _tick(battle, InputFrame.with_light_press(1))
    for _i in range(4):
        _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, 4955, "Rush Light has contacted Generic before duplicate snapshot")
    battle.fighter_a.combatant.hitstop_remaining = 0
    battle.fighter_b.combatant.hitstop_remaining = 0
    var snapshot := battle.capture_state()
    var hp_before := battle.fighter_b.combatant.hp
    var meter_before := battle.fighter_a.meter.get_value()
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, hp_before, "Rush active overlap does not duplicate damage before restore")
    t.equal(battle.fighter_a.meter.get_value(), meter_before, "Rush active overlap does not duplicate meter before restore")
    t.that(battle.restore_state(snapshot), "Rush duplicate-contact snapshot restores")
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, hp_before, "Rush duplicate damage remains suppressed after restore")
    t.equal(battle.fighter_a.meter.get_value(), meter_before, "Rush duplicate meter remains suppressed after restore")
