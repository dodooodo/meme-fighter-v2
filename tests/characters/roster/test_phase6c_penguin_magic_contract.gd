# Phase 6C real-runtime temporary-entity readability contracts.
class_name Phase6CPenguinMagicContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")

var t = ASSERT_HELPER.new()
var penguin: CharacterData
var magic: CharacterData
var generic: CharacterData

func run_all() -> int:
    penguin = RosterRegistry.character_by_id(&"tempura_penguin")
    magic = RosterRegistry.character_by_id(&"magic_orange_cat")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_penguin_waves_locks_cooldown_and_snapshot()
    _test_magic_trap_arming_replacement_and_snapshot()
    _test_magic_ultimate_warning_escape_and_snapshot()
    print("\nPhase 6C Penguin/Magic contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData, ax: int = 50000, bx: int = 56000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _move_from_set(move_set: MoveSetData, move_id: StringName) -> MoveData:
    if move_set == null:
        return null
    for move: MoveData in move_set.moves:
        if move != null and move.id == move_id:
            return move
    return null

func _penguin_summon() -> SummonData:
    return _move_from_set(penguin.move_set, MoveIds.ULTIMATE).on_start_effects[0].summon

func _magic_area(move_id: StringName) -> AreaData:
    var move := _move_from_set(magic.move_set, move_id)
    return move.on_start_effects[0].area if move != null else null

func _magic_sequence() -> SequenceData:
    return _move_from_set(magic.move_set, MoveIds.ULTIMATE).on_start_effects[0].sequence

func _active_summons(battle: BattleSimulation) -> Array[TemporaryEntityRuntime]:
    var out: Array[TemporaryEntityRuntime] = []
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == TemporaryEntityRuntime.Kind.SUMMON:
            out.append(runtime)
    return out

func _attack_capable_count(battle: BattleSimulation) -> int:
    var count := 0
    for runtime: TemporaryEntityRuntime in _active_summons(battle):
        if runtime.phase == 1 or runtime.phase == 2:
            count += 1
    return count

func _area_runtime(battle: BattleSimulation) -> TemporaryEntityRuntime:
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == TemporaryEntityRuntime.Kind.AREA:
            return runtime
    return null

func _sequence_runtime(battle: BattleSimulation) -> TemporaryEntityRuntime:
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == TemporaryEntityRuntime.Kind.SEQUENCE:
            return runtime
    return null

func _test_penguin_waves_locks_cooldown_and_snapshot() -> void:
    var data := _penguin_summon()
    var battle := _battle(penguin, generic)
    battle.temporary_entity_system.spawn_summon(battle.fighter_a, data)
    t.equal(_active_summons(battle).size(), 9, "Penguin Ultimate retains nine authored summon participants")
    t.equal(data.spawn_wave_size, 3, "Penguin summon authors three-per-wave readability")
    t.that(data.spawn_wave_interval_frames > 0, "Penguin summon authors deterministic wave spacing")
    t.equal(data.shared_group_target_lockout_frames, 12, "Penguin summon shared re-hit lock is 12F")
    t.equal(data.max_hits_per_owner_combo, 3, "Penguin summon cap is three hits per combo")
    t.equal(data.reaction_type, CombatReaction.Type.NONE, "Ordinary Penguin summon hit has no Knockdown reaction")
    t.that(data.attack_recovery_frames >= 105 and data.attack_recovery_frames <= 120, "Penguin per-minion recovery is in the 105-120F range")
    var windows: Array[int] = []
    var max_capable := 0
    var previous_capable := 0
    for _i in range(110):
        _tick(battle)
        var capable := _attack_capable_count(battle)
        max_capable = maxi(max_capable, capable)
        if capable == 3 and previous_capable != 3:
            windows.append(battle.frame_number)
        previous_capable = capable
    t.that(max_capable <= 3, "Penguin authoritative simultaneous attack-capable count never exceeds three")
    t.equal(windows.size(), 3, "Penguin wave scheduling exposes three distinct first-attack groups")
    if windows.size() == 3:
        t.that(windows[0] < windows[1] and windows[1] < windows[2], "Penguin waves are deterministically ordered")

    var contact_battle := _battle(penguin, generic, 50000, 57000)
    contact_battle.temporary_entity_system.spawn_summon(contact_battle.fighter_a, data)
    for runtime: TemporaryEntityRuntime in _active_summons(contact_battle):
        runtime.position_units = contact_battle.fighter_b.movement_motor.sim_position
    var summon_hit_frames: Array[int] = []
    for _i in range(110):
        _tick(contact_battle)
        for event: CombatEvent in contact_battle.drain_events():
            if event.type == CombatEvent.EventType.HIT and event.attack_source_kind == HitResult.AttackSourceKind.TEMPORARY_ENTITY:
                summon_hit_frames.append(event.frame_number)
    t.equal(summon_hit_frames.size(), 3, "Penguin real summon contact accepts no more than three combo hits")
    if summon_hit_frames.size() >= 2:
        t.that(summon_hit_frames[1] - summon_hit_frames[0] >= data.shared_group_target_lockout_frames, "Penguin shared lock suppresses adjacent same-wave summon hits")
    t.that(contact_battle.fighter_b.state_machine.state != FighterStateMachine.State.KNOCKDOWN, "Ordinary Penguin summon contact does not knock down defender")
    var cooldown_battle := _battle(penguin, generic, 50000, 57000)
    cooldown_battle.temporary_entity_system.spawn_summon(cooldown_battle.fighter_a, data)
    var tracked := _active_summons(cooldown_battle)[0]
    tracked.position_units = cooldown_battle.fighter_b.movement_motor.sim_position
    var attack_frames: Array[int] = []
    var last_serial := tracked.attack_serial
    for _i in range(180):
        _tick(cooldown_battle)
        if tracked.attack_serial != last_serial:
            attack_frames.append(cooldown_battle.frame_number)
            last_serial = tracked.attack_serial
    t.that(attack_frames.size() >= 2 and attack_frames[1] - attack_frames[0] >= data.attack_recovery_frames, "Penguin minion cannot re-attack before its authored cooldown")
    var corner_battle := _battle(penguin, generic, BattleSimulation.STAGE_RIGHT_UNITS - 6000, BattleSimulation.STAGE_RIGHT_UNITS - 12000)
    corner_battle.temporary_entity_system.spawn_summon(corner_battle.fighter_a, data)
    for _i in range(120): _tick(corner_battle)
    var corner_valid := true
    for runtime: TemporaryEntityRuntime in _active_summons(corner_battle):
        corner_valid = corner_valid and runtime.position_units.x >= BattleSimulation.STAGE_LEFT_UNITS and runtime.position_units.x <= BattleSimulation.STAGE_RIGHT_UNITS
    t.that(corner_valid and _attack_capable_count(corner_battle) <= 3, "Penguin corner swarm stays inside legal geometry without threat stacking")

    var snapshot_battle := _battle(penguin, generic)
    snapshot_battle.temporary_entity_system.spawn_summon(snapshot_battle.fighter_a, data)
    for _i in range(20): _tick(snapshot_battle)
    var snapshot := snapshot_battle.capture_state()
    for _i in range(80): _tick(snapshot_battle)
    var hash_a := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "Penguin pending waves snapshot restores")
    for _i in range(80): _tick(snapshot_battle)
    t.equal(snapshot_battle.state_signature(), hash_a, "Penguin wave scheduling restores identical authoritative hash")

func _test_magic_trap_arming_replacement_and_snapshot() -> void:
    for entry in [[&"magic_circle_l1", 30], [&"magic_circle_l2", 36], [&"magic_circle_l3", 42]]:
        var move_id: StringName = entry[0]
        var arm_frames: int = entry[1]
        var battle := _battle(magic, generic, 50000, 90000)
        battle.temporary_entity_system.spawn_area(battle.fighter_a, _magic_area(move_id))
        for _i in range(arm_frames - 1): _tick(battle)
        var runtime := _area_runtime(battle)
        var data := battle.temporary_entity_system.data_for_id(runtime.data_id) as AreaData
        t.that(not battle.temporary_entity_system._area_is_armed(runtime, data), "%s remains unarmed for its first %dF" % [move_id, arm_frames - 1])
        _tick(battle)
        t.that(battle.temporary_entity_system._area_is_armed(runtime, data), "%s arms on its authored frame" % move_id)

    var prearm_contact := _battle(magic, generic, 50000, 52000)
    prearm_contact.temporary_entity_system.spawn_area(prearm_contact.fighter_a, _magic_area(&"magic_circle_l1"))
    for _i in range(29): _tick(prearm_contact)
    t.equal(prearm_contact.fighter_b.combatant.hp, prearm_contact.fighter_b.data.max_hp, "Magic unarmed trap cannot damage a defender inside its area")

    var replacement := _battle(magic, generic, 50000, 90000)
    replacement.temporary_entity_system.spawn_area(replacement.fighter_a, _magic_area(&"magic_circle_l1"))
    for _i in range(30): _tick(replacement)
    replacement.temporary_entity_system.spawn_area(replacement.fighter_a, _magic_area(&"magic_circle_l3"))
    var current := _area_runtime(replacement)
    var current_data := replacement.temporary_entity_system.data_for_id(current.data_id) as AreaData
    t.equal(replacement.temporary_entity_system.active_entities().size(), 1, "Magic standard trap replacement retains exactly one active trap entity")
    t.that(not replacement.temporary_entity_system._area_is_armed(current, current_data), "Magic replacement trap starts unarmed")
    for _i in range(41): _tick(replacement)
    t.that(not replacement.temporary_entity_system._area_is_armed(current, current_data), "Magic Lv3 replacement cannot trigger before its full re-arm time")
    _tick(replacement)
    t.that(replacement.temporary_entity_system._area_is_armed(current, current_data), "Magic Lv3 replacement arms after its full 42F")
    var snapshot := replacement.capture_state()
    _tick(replacement)
    var hash_a := replacement.state_signature()
    t.that(replacement.restore_state(snapshot), "Magic armed replacement snapshot restores")
    _tick(replacement)
    t.equal(replacement.state_signature(), hash_a, "Magic replacement restores identical hash and arm state")
    var corner_guard := _battle(magic, generic, BattleSimulation.STAGE_RIGHT_UNITS - 9000, BattleSimulation.STAGE_RIGHT_UNITS - 3000)
    corner_guard.temporary_entity_system.spawn_area(corner_guard.fighter_a, _magic_area(&"magic_circle_l1"))
    for _i in range(30): _tick(corner_guard)
    for _i in range(19): _tick(corner_guard, null, InputFrame.new(corner_guard.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD, 0, 0))
    t.equal(corner_guard.fighter_b.combatant.hp, corner_guard.fighter_b.data.max_hp, "Magic corner trap setup retains a deterministic guard escape")

func _test_magic_ultimate_warning_escape_and_snapshot() -> void:
    var sequence := _magic_sequence()
    t.equal(sequence.steps.size(), 4, "Magic Ultimate authors exactly four warned attack zones")
    for step: SequenceStepData in sequence.steps:
        t.that(step.telegraph_frames >= 24 and step.telegraph_frames <= 30, "Magic Ultimate zone warning is inside the 24-30F contract")
    var activation_battle := _battle(magic, generic, 50000, 90000)
    activation_battle.temporary_entity_system.spawn_sequence(activation_battle.fighter_a, sequence)
    var activations: Array[int] = []
    var previous_mask := 0
    for _i in range(100):
        _tick(activation_battle)
        var active_runtime := _sequence_runtime(activation_battle)
        if active_runtime != null and active_runtime.sequence_step_mask != previous_mask:
            activations.append(activation_battle.frame_number)
            previous_mask = active_runtime.sequence_step_mask
    t.equal(activations, [24, 48, 72, 96], "Magic four warned zones activate on deterministic 24F intervals")
    var battle := _battle(magic, generic, 50000, 35000)
    battle.temporary_entity_system.spawn_sequence(battle.fighter_a, sequence)
    for _i in range(23): _tick(battle, null, InputFrame.new(battle.frame_number + 1, -1, 0, 0, 0, 0))
    t.equal(battle.fighter_b.combatant.hp, battle.fighter_b.data.max_hp, "Magic defender remains unharmed throughout first zone warning")
    _tick(battle, null, InputFrame.new(battle.frame_number + 1, -1, 0, 0, 0, 0))
    t.equal(battle.fighter_b.combatant.hp, battle.fighter_b.data.max_hp, "Magic defender can move away from the warned first zone")

    var hit_battle := _battle(magic, generic, 50000, 65000)
    hit_battle.temporary_entity_system.spawn_sequence(hit_battle.fighter_a, sequence)
    hit_battle.fighter_b.movement_motor.sim_position.x = 35000
    for _i in range(24): _tick(hit_battle)
    t.that(hit_battle.fighter_b.combatant.hp < hit_battle.fighter_b.data.max_hp, "Magic warned zone retains authored hit result when defender remains inside")
    var block_battle := _battle(magic, generic, 50000, 65000)
    block_battle.temporary_entity_system.spawn_sequence(block_battle.fighter_a, sequence)
    block_battle.fighter_b.movement_motor.sim_position.x = 35000
    for _i in range(23): _tick(block_battle)
    _tick(block_battle, null, InputFrame.new(block_battle.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD, 0, 0))
    t.equal(block_battle.fighter_b.combatant.hp, block_battle.fighter_b.data.max_hp, "Magic warned zone remains guardable on its activation frame")
    var runtime := _sequence_runtime(battle)
    var snapshot := battle.capture_state()
    for _i in range(90): _tick(battle)
    var hash_a := battle.state_signature()
    t.that(runtime != null and battle.restore_state(snapshot), "Magic warned Ultimate sequence snapshot restores")
    for _i in range(90): _tick(battle)
    t.equal(battle.state_signature(), hash_a, "Magic Ultimate warning sequence restores identical hash")
