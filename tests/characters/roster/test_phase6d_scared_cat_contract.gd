# Phase 6D real-runtime contracts for Scared Cat's optional Panic Exit and Husky.
class_name Phase6DScaredCatContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")

var t = ASSERT_HELPER.new()
var scared: CharacterData
var generic: CharacterData

func run_all() -> int:
    scared = RosterRegistry.character_by_id(&"scared_cat")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_panic_exit_optional_consumption_expiry_refresh_and_snapshot()
    _test_husky_singleton_hp_timing_interaction_and_snapshot()
    print("\nPhase 6D Scared Cat contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(ax: int = 50000, bx: int = 56000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(scared, generic, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _input(frame: int, x: int, buttons: int = 0) -> InputFrame:
    return InputFrame.new(frame, x, 0, buttons, 0, 0)

func _start_active_move(fighter: Fighter, move_id: StringName) -> MoveData:
    var move := fighter.move_registry.get_move(move_id)
    fighter.move_runner.interrupt()
    if move != null:
        fighter.move_runner.start_move(move)
        fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
        fighter.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
        fighter.move_runner.move_frame = move.first_active_frame()
    return move

func _panic_data() -> StatusEffectData:
    return scared.mechanics.statuses[0] as StatusEffectData

func _husky_data() -> SummonData:
    var ultimate := scared.move_set.moves.filter(func(move: MoveData) -> bool: return move != null and move.id == MoveIds.ULTIMATE)[0] as MoveData
    return ultimate.on_start_effects[0].summon as SummonData

func _summon_husky_via_ultimate(battle: BattleSimulation) -> void:
    var ultimate := battle.fighter_a.move_registry.get_move(MoveIds.ULTIMATE)
    battle.combat_resolver.effect_executor.execute_all(
        ultimate.on_start_effects,
        battle.fighter_a,
        battle.fighter_b,
        battle.temporary_entity_system,
        GameplayConditionEvaluator.contact_flags(battle.fighter_b),
        BattleSimulation.STAGE_LEFT_UNITS,
        BattleSimulation.STAGE_RIGHT_UNITS
    )

func _active_huskies(battle: BattleSimulation) -> Array[TemporaryEntityRuntime]:
    var out: Array[TemporaryEntityRuntime] = []
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == TemporaryEntityRuntime.Kind.SUMMON and runtime.data_id == &"husky_guardian":
            out.append(runtime)
    return out

func _perform_backstep(battle: BattleSimulation) -> void:
    _tick(battle, _input(battle.frame_number + 1, -1))
    _tick(battle, _input(battle.frame_number + 1, 0))
    _tick(battle, _input(battle.frame_number + 1, -1))

func _attack_timeline(battle: BattleSimulation) -> Dictionary:
    var fighter := battle.fighter_a
    var move := _start_active_move(fighter, MoveIds.STAND_HEAVY)
    var elapsed := 0
    var first_active := -1
    while move != null and fighter.move_runner.is_running() and elapsed < 120:
        _tick(battle)
        elapsed += 1
        if fighter.move_runner.is_running() and fighter.move_runner.phase() == &"ACTIVE" and first_active < 0:
            first_active = elapsed
    return {"first_active": first_active, "completion": elapsed}

func _test_panic_exit_optional_consumption_expiry_refresh_and_snapshot() -> void:
    var panic := _panic_data()
    var trigger := _battle()
    _start_active_move(trigger.fighter_a, MoveIds.STAND_LIGHT)
    _tick(trigger)
    t.that(trigger.fighter_a.has_status(&"panic_exit"), "Panic Exit is granted by Scared Cat's real successful-hit path")
    t.equal(trigger.fighter_a.statuses.remaining_frames(&"panic_exit"), panic.duration_frames, "Panic Exit begins from its authored 120F duration")
    var after_trigger := trigger.fighter_a.movement_motor.sim_position
    for _i in range(5): _tick(trigger)
    t.equal(trigger.fighter_a.movement_motor.sim_position, after_trigger, "Panic Exit activation creates no automatic retreat or forced movement")

    var illegal := _battle()
    illegal.fighter_a.statuses.apply(panic)
    illegal.fighter_a.combatant.hitstun_remaining = 10
    illegal.fighter_a.state_machine.transition_to(FighterStateMachine.State.HITSTUN)
    _perform_backstep(illegal)
    t.that(illegal.fighter_a.has_status(&"panic_exit"), "Illegal Backstep input does not consume pending Panic Exit")
    illegal.fighter_a.combatant.hitstun_remaining = 0
    illegal.fighter_a.state_machine.transition_to(FighterStateMachine.State.IDLE)
    for _i in range(5): _tick(illegal)
    _perform_backstep(illegal)
    t.that(not illegal.fighter_a.has_status(&"panic_exit") and illegal.fighter_a.mechanics_runtime.panic_backstep_active(), "First legal Backstep consumes Panic Exit at committed transition and enables enhancement")
    var enhanced_displacement := 0
    var enhanced_start := illegal.fighter_a.movement_motor.sim_position.x
    _tick(illegal)
    enhanced_displacement = absi(illegal.fighter_a.movement_motor.sim_position.x - enhanced_start)
    var normal := _battle()
    _perform_backstep(normal)
    var normal_start := normal.fighter_a.movement_motor.sim_position.x
    _tick(normal)
    var normal_displacement := absi(normal.fighter_a.movement_motor.sim_position.x - normal_start)
    t.that(enhanced_displacement > normal_displacement, "Panic Exit enhanced Backstep uses the authored 1.45x movement profile")
    for _i in range(scared.backstep_move_frames + scared.backstep_recovery_frames + 2): _tick(illegal)
    _perform_backstep(illegal)
    t.that(not illegal.fighter_a.mechanics_runtime.panic_backstep_active(), "Second Backstep has no second Panic Exit enhancement")

    var expiry := _battle()
    var expiry_control := _battle()
    expiry.fighter_a.statuses.apply(panic)
    for _i in range(panic.duration_frames):
        _tick(expiry)
        _tick(expiry_control)
    t.that(not expiry.fighter_a.has_status(&"panic_exit") and expiry.fighter_a.movement_motor.sim_position == expiry_control.fighter_a.movement_motor.sim_position, "Panic Exit expiry removes the status without movement")
    expiry.fighter_a.statuses.apply(panic)
    for _i in range(20): _tick(expiry)
    expiry.fighter_a.statuses.apply(panic)
    t.equal(expiry.fighter_a.statuses.capture_state().size(), 1, "Panic Exit refresh keeps exactly one non-stacking stock")
    t.equal(expiry.fighter_a.status_remaining(&"panic_exit"), panic.duration_frames, "Panic Exit reapplication uses canonical status refresh duration")

    var attack_control := _battle()
    var attack_panic := _battle()
    attack_panic.fighter_a.statuses.apply(panic)
    t.equal(_attack_timeline(attack_panic), _attack_timeline(attack_control), "Pending Panic Exit leaves ordinary attack timing unchanged")

    var snapshot_battle := _battle()
    snapshot_battle.fighter_a.statuses.apply(panic)
    _tick(snapshot_battle)
    var remaining := snapshot_battle.fighter_a.status_remaining(&"panic_exit")
    var snapshot := snapshot_battle.capture_state()
    _perform_backstep(snapshot_battle)
    for _i in range(16): _tick(snapshot_battle)
    var hash_a := snapshot_battle.state_signature()
    var position_a := snapshot_battle.fighter_a.movement_motor.sim_position
    t.that(snapshot_battle.restore_state(snapshot), "Panic Exit pending state restores through canonical snapshot")
    t.equal(snapshot_battle.fighter_a.status_remaining(&"panic_exit"), remaining, "Panic Exit snapshot restores remaining duration")
    _perform_backstep(snapshot_battle)
    for _i in range(16): _tick(snapshot_battle)
    t.equal(snapshot_battle.fighter_a.movement_motor.sim_position, position_a, "Panic Exit restore reproduces enhanced Backstep displacement")
    t.equal(snapshot_battle.state_signature(), hash_a, "Panic Exit restore reproduces identical authoritative hash")

func _test_husky_singleton_hp_timing_interaction_and_snapshot() -> void:
    var husky := _husky_data()
    var summon := _battle(50000, 62000)
    _summon_husky_via_ultimate(summon)
    t.equal(_active_huskies(summon).size(), 1, "Real Husky summon runtime creates exactly one active companion")
    var first_id := _active_huskies(summon)[0].instance_id
    _summon_husky_via_ultimate(summon)
    t.equal(_active_huskies(summon).size(), 1, "Second Husky summon deterministically replaces rather than stacks")
    t.that(_active_huskies(summon)[0].instance_id != first_id, "Replacement Husky receives a new deterministic entity instance")
    var runtime := _active_huskies(summon)[0]
    t.equal(runtime.hp, 160, "Husky uses generic temporary-entity HP of 160")

    runtime.position_units = summon.fighter_b.movement_motor.sim_position
    var startup_frame := -1
    var previous_serial := runtime.attack_serial
    for _i in range(24):
        _tick(summon)
        if runtime.attack_serial != previous_serial and startup_frame < 0:
            startup_frame = summon.frame_number
            previous_serial = runtime.attack_serial
    t.equal(startup_frame, husky.attack_startup_frames + 1, "Husky Bark reaches its first active hit after readable 18F startup")
    t.equal(husky.attack_recovery_frames, 120, "Husky Bark retains 120F authored cooldown")
    t.equal(husky.same_target_rehit_lockout_frames, 30, "Husky target re-hit lock is authored at 30F")
    var bark_frames: Array[int] = [startup_frame]
    for _i in range(180):
        _tick(summon)
        if runtime.attack_serial > bark_frames.size():
            bark_frames.append(summon.frame_number)
    t.that(bark_frames.size() >= 2 and bark_frames[1] - bark_frames[0] >= husky.attack_recovery_frames, "Real Husky runtime cannot Bark again before its authored 120F cooldown")
    t.that(bark_frames.size() < 3 or bark_frames[2] - bark_frames[1] >= husky.same_target_rehit_lockout_frames, "Husky real target contacts remain bounded by the 30F re-hit lock")

    var guarded := _battle(50000, 62000)
    _summon_husky_via_ultimate(guarded)
    _active_huskies(guarded)[0].position_units = guarded.fighter_b.movement_motor.sim_position
    for _i in range(22): _tick(guarded, null, _input(guarded.frame_number + 1, 0, InputFrame.InputButton.GUARD))
    t.equal(guarded.fighter_b.combatant.hp, guarded.fighter_b.data.max_hp, "Husky Bark remains blockable")

    var pressure := _battle(50000, 56000)
    _summon_husky_via_ultimate(pressure)
    _active_huskies(pressure)[0].position_units = pressure.fighter_b.movement_motor.sim_position
    _start_active_move(pressure.fighter_a, MoveIds.STAND_LIGHT)
    var husky_hits := 0
    for _i in range(220):
        _tick(pressure)
        for event: CombatEvent in pressure.drain_events():
            if event.type == CombatEvent.EventType.HIT and event.attack_source_kind == HitResult.AttackSourceKind.TEMPORARY_ENTITY:
                husky_hits += 1
    t.that(husky_hits <= 2, "Scared Cat normal plus Husky Bark pressure has no rapid re-hit loop")

    var damaged := _battle(50000, 62000)
    # The generic system permits any owner to spawn authored SummonData. Place
    # Husky in Scared Cat's real active Heavy path to verify entity HP damage.
    damaged.temporary_entity_system.spawn_summon(damaged.fighter_b, husky)
    var victim := _active_huskies(damaged)[0]
    # Scared Heavy's active claws are authored about 32-52 presentation pixels
    # ahead of the fighter; use that real active range rather than entity overlap.
    victim.position_units = damaged.fighter_a.movement_motor.sim_position + Vector2i(3100, -7200)
    _start_active_move(damaged.fighter_a, MoveIds.STAND_HEAVY)
    _tick(damaged)
    var after_first := _active_huskies(damaged)
    t.that(after_first.size() == 1 and after_first[0].hp < husky.max_hp, "Real fighter strike damages Husky through generic entity HP")
    for _i in range(8):
        var remaining := _active_huskies(damaged)
        if remaining.is_empty():
            break
        remaining[0].position_units = damaged.fighter_a.movement_motor.sim_position + Vector2i(3100, -7200)
        _start_active_move(damaged.fighter_a, MoveIds.STAND_HEAVY)
        _tick(damaged)
    t.equal(_active_huskies(damaged).size(), 0, "Husky removal is authoritative immediately at zero HP")
    _summon_husky_via_ultimate(damaged)
    t.equal(_active_huskies(damaged).size(), 1, "Husky can be resummoned after legitimate removal")

    var corner := _battle(BattleSimulation.STAGE_RIGHT_UNITS - 13000, BattleSimulation.STAGE_RIGHT_UNITS - 6000)
    _summon_husky_via_ultimate(corner)
    for _i in range(160): _tick(corner)
    var legal_corner := true
    for entity: TemporaryEntityRuntime in _active_huskies(corner):
        legal_corner = legal_corner and entity.position_units.x >= BattleSimulation.STAGE_LEFT_UNITS and entity.position_units.x <= BattleSimulation.STAGE_RIGHT_UNITS
    t.that(legal_corner and _active_huskies(corner).size() <= 1, "Husky corner pressure remains bounded without entity overlap or summon stacking")

    var snapshot_battle := _battle(50000, 62000)
    snapshot_battle.fighter_a.statuses.apply(_panic_data())
    _summon_husky_via_ultimate(snapshot_battle)
    var snapshot_husky := _active_huskies(snapshot_battle)[0]
    snapshot_husky.position_units = snapshot_battle.fighter_b.movement_motor.sim_position
    snapshot_husky.hp = 80
    for _i in range(8): _tick(snapshot_battle)
    var snapshot := snapshot_battle.capture_state()
    _perform_backstep(snapshot_battle)
    for _i in range(140): _tick(snapshot_battle)
    var hash_a := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "Panic Exit plus partial-HP Husky snapshot restores")
    t.equal(_active_huskies(snapshot_battle)[0].hp, 80, "Husky snapshot restores generic entity HP")
    _perform_backstep(snapshot_battle)
    for _i in range(140): _tick(snapshot_battle)
    t.equal(snapshot_battle.state_signature(), hash_a, "Panic Exit and Husky replay restore identical authoritative hash")
