# Phase 6G real-runtime Counter and Last Stand contracts for Bao La.
class_name Phase6GBaoContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var bao: CharacterData
var generic: CharacterData

func run_all() -> int:
    bao = RosterRegistry.character_by_id(&"bao_la")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_counter_contract()
    _test_last_stand_contract()
    print("\nPhase 6G Bao contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData = null, b: CharacterData = null) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a if a != null else generic, b if b != null else bao, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(59000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _start(fighter: Fighter, id: StringName, frame: int = -1) -> MoveData:
    var move := fighter.move_registry.get_move(id)
    fighter.move_runner.interrupt()
    if move != null:
        fighter.move_runner.start_move(move)
        fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
        fighter.mechanics_runtime.begin_move_defenses(move, fighter.move_runner.attack_instance_id)
        fighter.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
        fighter.move_runner.move_frame = move.first_active_frame() if frame < 0 else frame
    return move

func _prepare_confirmed_contact(battle: BattleSimulation) -> void:
    battle.fighter_a.combatant.hitstop_remaining = 0
    battle.fighter_b.combatant.hitstop_remaining = 0
    battle.fighter_a.movement_motor.sim_position.x = 50000
    battle.fighter_b.movement_motor.sim_position.x = 55000
    battle.fighter_a.movement_motor.facing = 1
    battle.fighter_b.movement_motor.facing = -1

func _strike_result(battle: BattleSimulation, kind: int) -> HitResult:
    var result := HitResult.new()
    result.result_type = HitResult.ResultType.HIT
    result.attack_source_kind = kind
    result.damage = 100
    result.hitstun_frames = 12
    result.hitstop_defender = 0
    return battle.combat_resolver.resolve_world_result(result, battle.fighter_a, battle.fighter_b)

func _test_counter_contract() -> void:
    var charge := _battle()
    charge.fighter_b.state_machine.transition_to(FighterStateMachine.State.CHARGE)
    t.equal(_strike_result(charge, HitResult.AttackSourceKind.FIGHTER_BODY).result_type, HitResult.ResultType.HIT, "Bao Charge has no Strike counter/armor")
    t.equal(_strike_result(charge, HitResult.AttackSourceKind.PROJECTILE).result_type, HitResult.ResultType.HIT, "Bao Charge has no Projectile counter/armor")
    _prepare_confirmed_contact(charge)
    var charge_throw_move := _start(charge.fighter_a, MoveIds.GROUND_THROW)
    charge.fighter_a.state_machine.transition_to(FighterStateMachine.State.THROW)
    charge.fighter_a.move_runner.move_frame = charge_throw_move.first_active_frame()
    var charge_throw_contact := charge.throw_system.build_throw_contact(charge.fighter_a, charge.fighter_b)
    t.that(charge_throw_contact != null, "Real ThrowSystem overlaps charging Bao")
    if charge_throw_contact != null:
        var charge_throw_result := charge.combat_resolver.resolve_confirmed_throw(charge_throw_contact, charge.fighter_a, charge.fighter_b)
        charge.combat_resolver.apply_throw_result(1, charge_throw_result, charge.fighter_a, charge.fighter_b, [])
        t.equal(charge.fighter_b.combatant.last_result_type, HitResult.ResultType.THROW, "Bao Charge has no Throw protection")

    for entry in [[&"bao_counter_l1", CounterData.SourceMask.STRIKE], [&"bao_counter_l2", CounterData.SourceMask.STRIKE], [&"bao_counter_l3", CounterData.SourceMask.STRIKE | CounterData.SourceMask.PROJECTILE]]:
        var battle := _battle()
        var move := _start(battle.fighter_b, entry[0], 3)
        t.equal(move.counter_data.valid_source_mask, entry[1], "%s keeps typed Counter eligibility" % String(entry[0]))
        t.equal(_strike_result(battle, HitResult.AttackSourceKind.FIGHTER_BODY).result_type, HitResult.ResultType.COUNTERED, "%s counters Strike on release" % String(entry[0]))
        var projectile_result := _strike_result(battle, HitResult.AttackSourceKind.PROJECTILE)
        var expected := HitResult.ResultType.COUNTERED if entry[0] == &"bao_counter_l3" else HitResult.ResultType.HIT
        t.equal(projectile_result.result_type, expected, "%s projectile eligibility is authored" % String(entry[0]))

    for id: StringName in [&"bao_counter_l1", &"bao_counter_l2", &"bao_counter_l3"]:
        var throw_battle := _battle()
        _prepare_confirmed_contact(throw_battle)
        _start(throw_battle.fighter_b, id, 3)
        var throw_move := _start(throw_battle.fighter_a, MoveIds.GROUND_THROW)
        throw_battle.fighter_a.state_machine.transition_to(FighterStateMachine.State.THROW)
        throw_battle.fighter_a.move_runner.move_frame = throw_move.first_active_frame()
        var contact := throw_battle.throw_system.build_throw_contact(throw_battle.fighter_a, throw_battle.fighter_b)
        t.that(contact != null, "Real ThrowSystem overlaps %s Counter" % String(id))
        if contact != null:
            var result := throw_battle.combat_resolver.resolve_confirmed_throw(contact, throw_battle.fighter_a, throw_battle.fighter_b)
            throw_battle.combat_resolver.apply_throw_result(1, result, throw_battle.fighter_a, throw_battle.fighter_b, [])
            t.equal(throw_battle.fighter_b.combatant.last_result_type, HitResult.ResultType.THROW, "Throw beats %s Counter" % String(id))

    var whiff := _battle()
    var l1 := _start(whiff.fighter_b, &"bao_counter_l1", 3)
    for _i in range(l1.recovery_frames + 4): _tick(whiff)
    t.that(not whiff.fighter_b.move_runner.is_running(), "Counter release whiffs into authored completion")

    var snapshot_battle := _battle()
    _start(snapshot_battle.fighter_b, &"bao_counter_l3", 3)
    var snapshot := snapshot_battle.capture_state()
    var result_a := _strike_result(snapshot_battle, HitResult.AttackSourceKind.PROJECTILE).result_type
    var hash := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "Bao counter snapshot restores")
    t.equal(_strike_result(snapshot_battle, HitResult.AttackSourceKind.PROJECTILE).result_type, result_a, "Counter projectile eligibility restores")
    t.equal(snapshot_battle.state_signature(), hash, "Counter snapshot restores identical hash")

func _enter_last_stand(battle: BattleSimulation, duration: int = 120) -> void:
    battle.fighter_b.mode.enter(&"last_stand", duration, battle.frame_number)
    battle.fighter_b.sync_mechanics_from_mode()
    battle.fighter_b.resources.set_value(&"resolve", 0)

func _test_last_stand_contract() -> void:
    var entry := _battle()
    _enter_last_stand(entry)
    t.equal(entry.fighter_b.mode.remaining_frames, 120, "Last Stand duration is 120F")
    t.equal(entry.fighter_b.resources.get_value(&"resolve"), 0, "Last Stand enters at Resolve 0")
    t.equal(entry.fighter_b.mode.movement_permille(&"walk_forward"), 1120, "Last Stand has authored 1.12x forward walk")

    for button in [InputFrame.InputButton.LIGHT, InputFrame.InputButton.HEAVY, InputFrame.InputButton.SPECIAL, InputFrame.InputButton.ULTIMATE]:
        _tick(entry, null, InputFrame.new(entry.frame_number + 1, 0, 0, button, button, 0))
        t.equal(entry.fighter_b.move_runner.current_move_id(), &"", "Last Stand rejects offensive input %d" % button)
    var throw_input := _battle()
    _enter_last_stand(throw_input)
    _tick(throw_input, null, InputFrame.new(throw_input.frame_number + 1, -1))
    _tick(throw_input, null, InputFrame.new(throw_input.frame_number + 1, 0, 0, InputFrame.InputButton.HEAVY, InputFrame.InputButton.HEAVY))
    t.equal(throw_input.fighter_b.move_runner.current_move_id(), &"", "Last Stand rejects normal Throw input")

    var before_walk := entry.fighter_b.movement_motor.sim_position.x
    _tick(entry, null, InputFrame.new(entry.frame_number + 1, -1))
    t.that(entry.fighter_b.movement_motor.sim_position.x != before_walk, "Last Stand permits walking")
    _tick(entry, null, InputFrame.new(entry.frame_number + 1, 0, 1))
    t.that(entry.fighter_b.movement_motor.is_airborne(), "Last Stand permits jumping")
    var mobility := _battle()
    _enter_last_stand(mobility)
    _tick(mobility, null, InputFrame.new(mobility.frame_number + 1, 1))
    _tick(mobility, null, InputFrame.new(mobility.frame_number + 1, 0))
    _tick(mobility, null, InputFrame.new(mobility.frame_number + 1, 1))
    t.equal(mobility.fighter_b.state_machine.state, FighterStateMachine.State.BACKSTEP, "Last Stand permits ordinary Backstep")

    var normal := _battle()
    _start(normal.fighter_a, MoveIds.STAND_LIGHT)
    _tick(normal)
    var normal_damage := normal.fighter_b.combatant.max_hp - normal.fighter_b.combatant.hp
    var standing := _battle()
    _enter_last_stand(standing)
    _prepare_confirmed_contact(standing)
    _start(standing.fighter_a, MoveIds.STAND_LIGHT)
    _tick(standing)
    t.equal(standing.fighter_b.combatant.max_hp - standing.fighter_b.combatant.hp, normal_damage, "Last Stand receives full ordinary damage")
    t.equal(standing.fighter_b.resources.get_value(&"resolve"), 1, "First valid Last Stand hit gains Resolve")
    var lock := standing.fighter_b.mechanics_runtime.last_stand_resolve_gain_lock_remaining
    t.equal(lock, 20, "Resolve gain lock is authored at 20F")
    _prepare_confirmed_contact(standing)
    standing.fighter_b.combatant.hitstun_remaining = 0
    standing.fighter_b.state_machine.transition_to(FighterStateMachine.State.IDLE)
    _start(standing.fighter_a, MoveIds.STAND_LIGHT)
    _tick(standing)
    t.equal(standing.fighter_b.resources.get_value(&"resolve"), 1, "Resolve lock rejects immediate multihit gain")
    # The deterministic lock pauses during the same combat hitstop as other mechanic timers.
    for _i in range(24): _tick(standing)
    _prepare_confirmed_contact(standing)
    standing.fighter_b.combatant.hitstun_remaining = 0
    standing.fighter_b.state_machine.transition_to(FighterStateMachine.State.IDLE)
    _start(standing.fighter_a, MoveIds.STAND_LIGHT)
    _tick(standing)
    t.equal(standing.fighter_b.resources.get_value(&"resolve"), 2, "Resolve gain resumes after lock")
    standing.fighter_b.resources.set_value(&"resolve", 3)
    standing.fighter_b.mechanics_runtime.last_stand_resolve_gain_lock_remaining = 0
    _start(standing.fighter_a, MoveIds.STAND_LIGHT)
    _tick(standing)
    t.equal(standing.fighter_b.resources.get_value(&"resolve"), 3, "Resolve remains capped at 3")

    var thrown := _battle()
    _enter_last_stand(thrown)
    _prepare_confirmed_contact(thrown)
    thrown.fighter_b.resources.set_value(&"resolve", 3)
    var throw_move := _start(thrown.fighter_a, MoveIds.GROUND_THROW)
    thrown.fighter_a.state_machine.transition_to(FighterStateMachine.State.THROW)
    thrown.fighter_a.move_runner.move_frame = throw_move.first_active_frame()
    var throw_contact := thrown.throw_system.build_throw_contact(thrown.fighter_a, thrown.fighter_b)
    t.that(throw_contact != null, "Real ThrowSystem overlaps Last Stand Bao")
    if throw_contact != null:
        var throw_result := thrown.combat_resolver.resolve_confirmed_throw(throw_contact, thrown.fighter_a, thrown.fighter_b)
        thrown.combat_resolver.apply_throw_result(1, throw_result, thrown.fighter_a, thrown.fighter_b, [])
        t.equal(thrown.fighter_b.mode.active_mode_id, &"", "Throw ends Last Stand")
        t.equal(thrown.fighter_b.resources.get_value(&"resolve"), 0, "Throw clears Resolve without cashout")
    var thrown_zero := _battle()
    _enter_last_stand(thrown_zero)
    _prepare_confirmed_contact(thrown_zero)
    var zero_throw_move := _start(thrown_zero.fighter_a, MoveIds.GROUND_THROW)
    thrown_zero.fighter_a.state_machine.transition_to(FighterStateMachine.State.THROW)
    thrown_zero.fighter_a.move_runner.move_frame = zero_throw_move.first_active_frame()
    var zero_throw_contact := thrown_zero.throw_system.build_throw_contact(thrown_zero.fighter_a, thrown_zero.fighter_b)
    t.that(zero_throw_contact != null, "Real ThrowSystem overlaps Resolve 0 Last Stand Bao")
    if zero_throw_contact != null:
        var zero_throw_result := thrown_zero.combat_resolver.resolve_confirmed_throw(zero_throw_contact, thrown_zero.fighter_a, thrown_zero.fighter_b)
        thrown_zero.combat_resolver.apply_throw_result(1, zero_throw_result, thrown_zero.fighter_a, thrown_zero.fighter_b, [])
        t.equal(thrown_zero.fighter_b.mode.active_mode_id, &"", "Throw at Resolve 0 ends Last Stand")
        t.equal(thrown_zero.fighter_b.resources.get_value(&"resolve"), 0, "Throw at Resolve 0 keeps Resolve cleared")

    for tier in [0, 1, 2, 3]:
        var expiry := _battle()
        _enter_last_stand(expiry, 1)
        expiry.fighter_b.resources.set_value(&"resolve", tier)
        _tick(expiry)
        var move := expiry.fighter_b.move_runner.current_move
        t.equal(move.id if move != null else &"", &"bao_last_stand_%d" % tier, "Last Stand expiry routes Resolve %d" % tier)
        t.equal(expiry.fighter_b.resources.get_value(&"resolve"), 0, "Last Stand expiry clears Resolve %d" % tier)
    var zero := _battle()
    _enter_last_stand(zero, 1)
    _tick(zero)
    var zero_move := zero.fighter_b.move_runner.current_move
    t.equal(zero_move.damage if zero_move != null else -1, 0, "Resolve 0 expiry has no damage")
    t.equal(zero_move.recovery_frames if zero_move != null else -1, 11, "Resolve 0 expiry has 11F committed recovery")
    var tier_one := entry.fighter_b.move_registry.get_move(&"bao_last_stand_1")
    var tier_two := entry.fighter_b.move_registry.get_move(&"bao_last_stand_2")
    var tier_three := entry.fighter_b.move_registry.get_move(&"bao_last_stand_3")
    t.equal(tier_one.damage, 55, "Resolve 1 keeps authored 55 damage")
    t.equal(tier_two.damage, 100, "Resolve 2 keeps authored 100 damage")
    t.equal(tier_two.reaction_type, CombatReaction.Type.HARD_KNOCKDOWN, "Resolve 2 keeps Hard Knockdown")
    t.equal(tier_three.damage, 155, "Resolve 3 keeps authored 155 damage")
    t.equal(tier_three.startup_frames, 12, "Resolve 3 has readable 12F telegraph")
    var guarded_cashout := _battle()
    _prepare_confirmed_contact(guarded_cashout)
    _tick(guarded_cashout, InputFrame.new(guarded_cashout.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD, InputFrame.InputButton.GUARD))
    _start(guarded_cashout.fighter_b, &"bao_last_stand_3")
    _tick(guarded_cashout, InputFrame.new(guarded_cashout.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD), null)
    t.equal(guarded_cashout.fighter_a.combatant.last_result_type, HitResult.ResultType.BLOCK, "Resolve cashout remains guardable")
    var whiff_cashout := _battle()
    whiff_cashout.fighter_a.movement_motor.sim_position.x = 50000
    whiff_cashout.fighter_b.movement_motor.sim_position.x = 90000
    _start(whiff_cashout.fighter_b, &"bao_last_stand_3")
    for _i in range(tier_three.active_frames + tier_three.recovery_frames + 3): _tick(whiff_cashout)
    t.that(not whiff_cashout.fighter_b.move_runner.is_running(), "Resolve cashout whiff completes its authored recovery")

    var snapshot_battle := _battle()
    _enter_last_stand(snapshot_battle)
    _start(snapshot_battle.fighter_a, MoveIds.STAND_LIGHT)
    _tick(snapshot_battle)
    var snapshot := snapshot_battle.capture_state()
    var hash := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "Last Stand Resolve-lock snapshot restores")
    t.equal(snapshot_battle.state_signature(), hash, "Last Stand Resolve-lock snapshot restores identical hash")
    var resolve_three_snapshot := _battle()
    _enter_last_stand(resolve_three_snapshot, 1)
    resolve_three_snapshot.fighter_b.resources.set_value(&"resolve", 3)
    var cashout_snapshot := resolve_three_snapshot.capture_state()
    _tick(resolve_three_snapshot)
    var cashout_hash := resolve_three_snapshot.state_signature()
    t.equal(resolve_three_snapshot.fighter_b.move_runner.current_move_id(), &"bao_last_stand_3", "Resolve 3 expiry begins its authored cashout")
    t.that(resolve_three_snapshot.restore_state(cashout_snapshot), "Pre-cashout snapshot restores")
    _tick(resolve_three_snapshot)
    t.equal(resolve_three_snapshot.state_signature(), cashout_hash, "Pre-cashout replay restores identical hash")
    var low_hp := _battle()
    low_hp.fighter_b.combatant.hp = 1
    _tick(low_hp)
    t.equal(low_hp.fighter_b.mode.active_mode_id, &"", "Low HP does not auto-enter Last Stand")
    t.equal(low_hp.fighter_b.resources.get_value(&"resolve"), 0, "Low HP does not grant free Resolve")
