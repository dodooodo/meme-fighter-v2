# Gate 2 deterministic character-mechanics snapshot scenarios.
# Each case creates authoritative gameplay state, captures/hash-checks it, mutates it,
# restores the snapshot, and verifies the restored fields and canonical hash.
class_name Gate2SnapshotScenarioTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_alien_signal_mark_snapshot()
    _test_alien_position_lock_snapshot()
    _test_doge_super_mode_snapshot()
    _test_penguin_summon_aux_snapshot()
    _test_magic_trap_arming_snapshot()
    _test_blade_dual_mode_snapshot()
    _test_pink_true_face_resource_snapshot()
    _test_pink_dash_cancel_snapshot()
    _test_sauce_sticky_extended_once_snapshot()
    _test_scared_panic_exit_snapshot()
    _test_husky_runtime_snapshot()
    _test_niu_courage_snapshot()
    _test_bao_last_stand_snapshot()
    print("\nGate 2 Snapshot Scenario tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a_id: StringName, b_id: StringName = &"doge") -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        RosterRegistry.character_by_id(a_id),
        RosterRegistry.character_by_id(b_id),
        null,
        null,
        Vector2i(50000, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(55000, BattleSimulation.GROUND_Y_UNITS)
    )
    return battle

func _status_definition(character: CharacterData, status_id: StringName) -> StatusEffectData:
    if character == null or character.mechanics == null:
        return null
    for data: StatusEffectData in character.mechanics.statuses:
        if data != null and data.id == status_id:
            return data
    return null

func _sequence_from_move(move: MoveData, sequence_id: StringName) -> SequenceData:
    if move == null:
        return null
    for effect: GameplayEffectData in move.on_start_effects:
        if effect != null and effect.sequence != null and effect.sequence.id == sequence_id:
            return effect.sequence
    for effect: GameplayEffectData in move.on_complete_effects:
        if effect != null and effect.sequence != null and effect.sequence.id == sequence_id:
            return effect.sequence
    return null

func _summon_from_move(move: MoveData, summon_id: StringName) -> SummonData:
    if move == null:
        return null
    for effect: GameplayEffectData in move.on_start_effects:
        if effect != null and effect.summon != null and effect.summon.id == summon_id:
            return effect.summon
    for effect: GameplayEffectData in move.on_complete_effects:
        if effect != null and effect.summon != null and effect.summon.id == summon_id:
            return effect.summon
    return null

func _area_from_move(move: MoveData, area_id: StringName) -> AreaData:
    if move == null:
        return null
    for effect: GameplayEffectData in move.on_start_effects:
        if effect != null and effect.area != null and effect.area.id == area_id:
            return effect.area
    return null

func _entity_by_id(battle: BattleSimulation, instance_id: int) -> TemporaryEntityRuntime:
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.instance_id == instance_id:
            return runtime
    return null

func _assert_hash_restored(battle: BattleSimulation, snapshot: BattleStateSnapshot, hash_a: String, label: String) -> void:
    t.that(battle.restore_state(snapshot), "%s restores" % label)
    t.equal(battle.state_signature(), hash_a, "%s restore reproduces canonical hash" % label)

func _test_alien_signal_mark_snapshot() -> void:
    var battle := _battle(&"alien_meow")
    var signal_mark := _status_definition(battle.fighter_a.data, &"signal_mark")
    t.that(signal_mark != null, "Alien Signal Mark definition resolves")
    if signal_mark == null:
        return
    t.that(battle.fighter_b.statuses.apply(signal_mark), "Alien Signal Mark enters authoritative target status state")
    var remaining := battle.fighter_b.statuses.remaining_frames(&"signal_mark")
    var serial := battle.fighter_b.statuses.application_serial(&"signal_mark")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_b.statuses.remove(&"signal_mark")
    _assert_hash_restored(battle, snapshot, hash_a, "Alien Signal Mark")
    t.that(battle.fighter_b.statuses.has_status(&"signal_mark"), "Alien Signal Mark identity survives restore")
    t.equal(battle.fighter_b.statuses.remaining_frames(&"signal_mark"), remaining, "Alien Signal Mark remaining duration survives restore")
    t.equal(battle.fighter_b.statuses.application_serial(&"signal_mark"), serial, "Alien Signal Mark application serial survives restore")

func _test_alien_position_lock_snapshot() -> void:
    var battle := _battle(&"alien_meow")
    var ultimate := battle.fighter_a.move_registry.get_move(MoveIds.ULTIMATE)
    var sequence := _sequence_from_move(ultimate, &"alien_position_lock")
    t.that(sequence != null, "Alien fixed Position Lock sequence resolves")
    if sequence == null:
        return
    battle.fighter_b.movement_motor.sim_position = Vector2i(56500, BattleSimulation.GROUND_Y_UNITS)
    var ids := battle.temporary_entity_system.spawn_sequence(battle.fighter_a, sequence)
    t.equal(ids.size(), 1, "Alien Position Lock creates one deterministic Sequence runtime")
    if ids.is_empty():
        return
    battle.temporary_entity_system.advance_existing(false, battle.fighter_a, battle.fighter_b)
    var runtime := _entity_by_id(battle, ids[0])
    t.that(runtime != null and runtime.recorded_positions.has(0), "Alien Position Lock records target coordinate before bombardment")
    if runtime == null or not runtime.recorded_positions.has(0):
        return
    var recorded: Vector2i = runtime.recorded_positions[0]
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    runtime.recorded_positions[0] = Vector2i(99999, 99999)
    battle.fighter_b.movement_motor.sim_position = Vector2i(70000, BattleSimulation.GROUND_Y_UNITS)
    _assert_hash_restored(battle, snapshot, hash_a, "Alien Position Lock")
    runtime = _entity_by_id(battle, ids[0])
    t.equal(runtime.recorded_positions.get(0, Vector2i.ZERO), recorded, "Alien recorded fixed coordinate survives restore")
    battle.fighter_b.movement_motor.sim_position = Vector2i(recorded.x + 18000, recorded.y)
    battle.temporary_entity_system.advance_existing(false, battle.fighter_a, battle.fighter_b)
    runtime = _entity_by_id(battle, ids[0])
    t.equal(runtime.recorded_positions.get(0, Vector2i.ZERO), recorded, "Alien Position Lock does not retarget to current opponent position after restore")

func _test_doge_super_mode_snapshot() -> void:
    var battle := _battle(&"doge")
    t.that(battle.fighter_a.mode.enter(&"super_doge", 333, battle.frame_number), "Super Doge mode enters through ModeComponent")
    battle.fighter_a.sync_mechanics_from_mode()
    var serial := battle.fighter_a.mode.mode_serial
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_a.mode.exit()
    battle.fighter_a.sync_mechanics_from_mode()
    _assert_hash_restored(battle, snapshot, hash_a, "Super Doge")
    t.equal(battle.fighter_a.mode.active_mode_id, &"super_doge", "Super Doge mode identity survives restore")
    t.equal(battle.fighter_a.mode.remaining_frames, 333, "Super Doge remaining duration survives restore")
    t.equal(battle.fighter_a.mode.mode_serial, serial, "Super Doge mode serial survives restore")

func _test_penguin_summon_aux_snapshot() -> void:
    var battle := _battle(&"tempura_penguin")
    var summon := _summon_from_move(battle.fighter_a.move_registry.get_move(MoveIds.ULTIMATE), &"penguin_swarm")
    t.that(summon != null, "Penguin swarm SummonData resolves")
    if summon == null:
        return
    battle.fighter_b.movement_motor.sim_position = Vector2i(53000, BattleSimulation.GROUND_Y_UNITS)
    var ids := battle.temporary_entity_system.spawn_summon(battle.fighter_a, summon)
    t.equal(ids.size(), 9, "Penguin snapshot setup owns all nine minions")
    if ids.is_empty():
        return
    battle.fighter_a.combo_scaling.register_confirmed_hit(battle.fighter_b.fighter_id, 1, false, false)
    var first := _entity_by_id(battle, ids[0])
    first.position_units = Vector2i(52500, BattleSimulation.GROUND_Y_UNITS)
    first.phase = 2
    first.phase_remaining = summon.attack_active_frames
    battle.temporary_entity_system.advance_existing(false, battle.fighter_a, battle.fighter_b)
    battle.temporary_entity_system.advance_existing(false, battle.fighter_a, battle.fighter_b)
    first = _entity_by_id(battle, ids[0])
    var aux := battle.temporary_entity_system.capture_aux_state()
    t.that(aux["shared_target_locks"].size() > 0, "Penguin shared target lock is active before snapshot")
    t.that(aux["combo_hit_count"].size() > 0, "Penguin owner-combo summon hit count is active before snapshot")
    t.equal(first.phase, 3, "Penguin first minion is in authored recovery/cooldown phase")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    var expected_aux: Dictionary = snapshot.temporary_entity_aux_state.duplicate(true)
    var expected_phase_remaining := first.phase_remaining
    battle.temporary_entity_system.clear_active()
    battle.fighter_a.combo_scaling.reset()
    _assert_hash_restored(battle, snapshot, hash_a, "Penguin summon aux state")
    t.equal(battle.temporary_entity_system.active_entities().size(), 9, "Penguin nine minions survive snapshot restore")
    t.equal(battle.temporary_entity_system.capture_aux_state(), expected_aux, "Penguin shared lock/rehit/combo counters survive restore")
    first = _entity_by_id(battle, ids[0])
    t.equal(first.phase_remaining, expected_phase_remaining, "Penguin individual summon cooldown survives restore")

func _test_magic_trap_arming_snapshot() -> void:
    var battle := _battle(&"magic_orange_cat")
    var trap_move := battle.fighter_a.move_registry.get_move(&"magic_circle_l2")
    var area := _area_from_move(trap_move, &"jpeg_circle")
    t.that(area != null and area.arm_frames == 36, "Mage Lv2 JPEG trap exposes canonical arming time")
    if area == null:
        return
    battle.fighter_b.movement_motor.sim_position = battle.fighter_a.movement_motor.sim_position
    var ids := battle.temporary_entity_system.spawn_area(battle.fighter_a, area)
    if ids.is_empty():
        t.that(false, "Mage JPEG trap runtime spawns")
        return
    var runtime := _entity_by_id(battle, ids[0])
    runtime.age_frames = 20
    t.that(not battle.temporary_entity_system.target_inside_owner_area(battle.fighter_a.fighter_id, battle.fighter_b.movement_motor.sim_position, &"jpeg_circle"), "Unarmed JPEG trap is excluded from active-area query")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    runtime.age_frames = area.arm_frames
    _assert_hash_restored(battle, snapshot, hash_a, "Mage trap arming state")
    runtime = _entity_by_id(battle, ids[0])
    t.equal(runtime.age_frames, 20, "Mage trap arming progress survives restore")
    t.that(not battle.temporary_entity_system.target_inside_owner_area(battle.fighter_a.fighter_id, battle.fighter_b.movement_motor.sim_position, &"jpeg_circle"), "Restored partially-armed trap remains inactive")
    for _i in range(area.arm_frames - runtime.age_frames):
        battle.temporary_entity_system.advance_existing(false, battle.fighter_a, battle.fighter_b)
    t.that(battle.temporary_entity_system.target_inside_owner_area(battle.fighter_a.fighter_id, battle.fighter_b.movement_motor.sim_position, &"jpeg_circle"), "Restored trap becomes active at the same deterministic arm frame")

func _test_blade_dual_mode_snapshot() -> void:
    var battle := _battle(&"blade_shield")
    t.that(battle.fighter_a.mode.enter(&"dual_blade", 301, battle.frame_number), "Blade Dual Mode enters")
    battle.fighter_a.sync_mechanics_from_mode()
    t.that(not battle.fighter_a.mode.guard_allowed(), "Blade Dual Mode has authoritative Guard disabled before snapshot")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_a.mode.exit()
    _assert_hash_restored(battle, snapshot, hash_a, "Blade Dual Mode")
    t.equal(battle.fighter_a.mode.active_mode_id, &"dual_blade", "Blade Dual Mode identity survives restore")
    t.equal(battle.fighter_a.mode.remaining_frames, 301, "Blade Dual Mode remaining duration survives restore")
    t.that(not battle.fighter_a.mode.guard_allowed(), "Blade Guard remains disabled after restore")

func _test_pink_true_face_resource_snapshot() -> void:
    var battle := _battle(&"pink_star")
    t.that(battle.fighter_a.resources.set_value(&"face_actions", 3), "Pink Face Actions setup accepts value 3")
    t.that(battle.fighter_a.mode.enter(&"true_face", 0, battle.frame_number), "Pink True Face mode enters")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_a.resources.set_value(&"face_actions", 0)
    battle.fighter_a.mode.exit()
    _assert_hash_restored(battle, snapshot, hash_a, "Pink True Face resource")
    t.equal(battle.fighter_a.resources.get_value(&"face_actions"), 3, "Pink Face Actions value survives restore")
    t.equal(battle.fighter_a.mode.active_mode_id, &"true_face", "Pink True Face mode survives restore")

func _test_pink_dash_cancel_snapshot() -> void:
    var battle := _battle(&"pink_star")
    battle.fighter_a.resources.set_value(&"face_actions", 3)
    battle.fighter_a.mode.enter(&"true_face", 0, battle.frame_number)
    battle.fighter_a.combo_scaling.register_confirmed_hit(battle.fighter_b.fighter_id, 35, false, false)
    battle.fighter_a.combo_scaling.record_dash_cancel()
    t.equal(battle.fighter_a.combo_scaling.dash_cancel_count, 1, "Pink combo setup records one Dash Cancel")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_a.combo_scaling.reset()
    _assert_hash_restored(battle, snapshot, hash_a, "Pink Dash Cancel budget")
    t.equal(battle.fighter_a.combo_scaling.dash_cancel_count, 1, "Pink Dash Cancel count survives restore")
    t.that(not battle.fighter_a.combo_scaling.can_use_dash_cancel(1), "Restored Pink combo still rejects a second Dash Cancel")

func _test_sauce_sticky_extended_once_snapshot() -> void:
    var battle := _battle(&"sauce_stubble_dog")
    var sauce := _status_definition(battle.fighter_a.data, &"sauce")
    t.that(sauce != null, "Sauce Sticky status definition resolves")
    if sauce == null:
        return
    battle.fighter_b.statuses.apply(sauce)
    t.that(battle.fighter_b.statuses.extend_once(&"sauce", 60), "Sauce first extension is consumed before snapshot")
    var expected_remaining := battle.fighter_b.statuses.remaining_frames(&"sauce")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_b.statuses.remove(&"sauce")
    _assert_hash_restored(battle, snapshot, hash_a, "Sauce Sticky extension-used state")
    t.equal(battle.fighter_b.statuses.remaining_frames(&"sauce"), expected_remaining, "Sticky remaining duration survives restore")
    t.that(battle.fighter_b.statuses.extended_once(&"sauce"), "Sticky extended_once flag survives restore")
    t.that(not battle.fighter_b.statuses.extend_once(&"sauce", 60), "Restored Sticky rejects a second extension")

func _test_scared_panic_exit_snapshot() -> void:
    var battle := _battle(&"scared_cat")
    var panic := _status_definition(battle.fighter_a.data, &"panic_exit")
    t.that(panic != null, "Panic Exit status definition resolves")
    if panic == null:
        return
    battle.fighter_a.statuses.apply(panic)
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_a.statuses.remove(&"panic_exit")
    _assert_hash_restored(battle, snapshot, hash_a, "Scared Cat Panic Exit")
    t.that(battle.fighter_a.statuses.has_status(&"panic_exit"), "Panic Exit availability survives restore")

func _test_husky_runtime_snapshot() -> void:
    var battle := _battle(&"scared_cat")
    var husky := _summon_from_move(battle.fighter_a.move_registry.get_move(MoveIds.ULTIMATE), &"husky_guardian")
    t.that(husky != null, "Husky SummonData resolves")
    if husky == null:
        return
    battle.fighter_b.movement_motor.sim_position = Vector2i(53000, BattleSimulation.GROUND_Y_UNITS)
    var ids := battle.temporary_entity_system.spawn_summon(battle.fighter_a, husky)
    if ids.is_empty():
        t.that(false, "Husky runtime spawns")
        return
    var runtime := _entity_by_id(battle, ids[0])
    runtime.position_units = Vector2i(52500, BattleSimulation.GROUND_Y_UNITS)
    runtime.phase = 2
    runtime.phase_remaining = husky.attack_active_frames
    battle.temporary_entity_system.advance_existing(false, battle.fighter_a, battle.fighter_b)
    battle.temporary_entity_system.advance_existing(false, battle.fighter_a, battle.fighter_b)
    runtime = _entity_by_id(battle, ids[0])
    var aux := battle.temporary_entity_system.capture_aux_state()
    t.equal(runtime.phase, 3, "Husky enters recovery/cooldown phase before snapshot")
    t.that(aux["rehit_locks"].size() == 1, "Husky re-hit lock is active before snapshot")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    var expected_aux: Dictionary = snapshot.temporary_entity_aux_state.duplicate(true)
    var expected_hp := runtime.hp
    var expected_phase_remaining := runtime.phase_remaining
    battle.temporary_entity_system.clear_active()
    _assert_hash_restored(battle, snapshot, hash_a, "Husky runtime")
    runtime = _entity_by_id(battle, ids[0])
    t.equal(runtime.hp, expected_hp, "Husky HP survives restore")
    t.equal(runtime.phase_remaining, expected_phase_remaining, "Husky cooldown survives restore")
    t.equal(battle.temporary_entity_system.capture_aux_state(), expected_aux, "Husky re-hit runtime lock survives restore")

func _test_niu_courage_snapshot() -> void:
    var battle := _battle(&"niu_lai")
    t.that(battle.fighter_a.resources.set_value(&"courage", 2), "Niu Courage setup enters Lv2")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_a.resources.set_value(&"courage", 0)
    _assert_hash_restored(battle, snapshot, hash_a, "Niu Courage Lv2")
    t.equal(battle.fighter_a.resources.get_value(&"courage"), 2, "Niu Courage Lv2 survives restore")
    t.equal(battle.fighter_a.resources.dash_recovery_frames(battle.fighter_a.data.dash_recovery_frames), 4, "Restored Courage Lv2 deterministically derives 4F Dash Recovery")
    t.that(battle.fighter_a.resources.movement_permille(&"walk_forward") > 1000, "Restored Courage Lv2 deterministically derives forward-walk modifier")

func _test_bao_last_stand_snapshot() -> void:
    var battle := _battle(&"bao_la")
    battle.fighter_a.resources.set_value(&"resolve", 2)
    t.that(battle.fighter_a.mode.enter(&"last_stand", 91, battle.frame_number), "Bao Last Stand mode enters")
    battle.fighter_a.sync_mechanics_from_mode()
    t.that(battle.fighter_a.mechanics_runtime.last_stand_active, "Bao Last Stand authoritative mechanics flag is active")
    var snapshot := battle.capture_state()
    var hash_a := battle.state_signature()
    battle.fighter_a.resources.set_value(&"resolve", 0)
    battle.fighter_a.mode.exit()
    battle.fighter_a.sync_mechanics_from_mode()
    _assert_hash_restored(battle, snapshot, hash_a, "Bao Last Stand Resolve")
    t.equal(battle.fighter_a.resources.get_value(&"resolve"), 2, "Bao Resolve=2 survives restore")
    t.equal(battle.fighter_a.mode.active_mode_id, &"last_stand", "Bao Last Stand mode survives restore")
    t.equal(battle.fighter_a.mode.remaining_frames, 91, "Bao Last Stand remaining timer survives restore")
    t.that(battle.fighter_a.mechanics_runtime.last_stand_active, "Bao Last Stand control restriction is deterministically restored from mode")
