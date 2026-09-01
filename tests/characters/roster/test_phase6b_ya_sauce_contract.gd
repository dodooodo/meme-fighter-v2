# Phase 6B real-runtime locomotion-only contracts for YA Mouse and Sauce Stubble Dog.
class_name Phase6BYaSauceContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")

var t = ASSERT_HELPER.new()
var ya: CharacterData
var sauce: CharacterData
var generic: CharacterData
var doge: CharacterData

func run_all() -> int:
    ya = RosterRegistry.character_by_id(&"ya_mouse")
    sauce = RosterRegistry.character_by_id(&"sauce_stubble_dog")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    doge = RosterRegistry.character_by_id(&"doge")
    _test_ya_locomotion_only_floor_overlap_expiry_and_snapshot()
    _test_ya_attack_and_reaction_timing()
    _test_sauce_levels_and_locomotion_only()
    _test_sauce_extension_cap_expiry_and_cashout()
    _test_sauce_snapshot_hash_and_doge_sanity()
    print("\nPhase 6B YA/Sauce contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData, ax: int = 50000, bx: int = 90000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _guard(frame: int) -> InputFrame:
    return InputFrame.new(frame, 0, 0, InputFrame.InputButton.GUARD, 0, 0)

func _start_active_move(fighter: Fighter, move_id: StringName) -> MoveData:
    var move := fighter.move_registry.get_move(move_id)
    fighter.move_runner.interrupt()
    if move != null:
        fighter.move_runner.start_move(move)
        fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
        fighter.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
        fighter.move_runner.move_frame = move.first_active_frame()
    return move

func _move_from_set(move_set: MoveSetData, move_id: StringName) -> MoveData:
    if move_set == null:
        return null
    for move: MoveData in move_set.moves:
        if move != null and move.id == move_id:
            return move
    return null

func _ya_area(move_id: StringName) -> AreaData:
    var move := _move_from_set(ya.move_set, move_id)
    return move.on_start_effects[0].area if move != null and not move.on_start_effects.is_empty() else null

func _ya_slow_l3() -> StatusEffectData:
    var area := _ya_area(&"ya_wave_l3")
    return area.while_inside_status if area != null else null

func _sauce_status(move_id: StringName) -> StatusEffectData:
    var move := _move_from_set(sauce.move_set, move_id)
    if move == null or move.projectile_spawns.is_empty():
        return null
    var projectile: ProjectileData = move.projectile_spawns[0].projectile_data
    return projectile.on_hit_effects[0].status if projectile != null and not projectile.on_hit_effects.is_empty() else null

func _spawn_ya_area(battle: BattleSimulation, move_id: StringName) -> void:
    var area := _ya_area(move_id)
    battle.temporary_entity_system.spawn_area(battle.fighter_a, area)

func _apply_sauce_projectile(battle: BattleSimulation, move_id: StringName) -> StatusEffectData:
    var move := battle.fighter_a.move_registry.get_move(move_id)
    if move == null or move.projectile_spawns.is_empty():
        return null
    var descriptor := move.projectile_spawns[0]
    var runtime := battle.projectile_system.spawn_from_descriptor(battle.fighter_a, move_id, 0, descriptor)
    if runtime == null:
        return null
    runtime.position_units = battle.fighter_b.movement_motor.sim_position - Vector2i(descriptor.projectile_data.velocity_x_units_per_tick * runtime.facing, 0)
    _tick(battle)
    return descriptor.projectile_data.on_hit_effects[0].status

func _measure_locomotion(battle: BattleSimulation, fighter: Fighter, target_is_b: bool) -> Dictionary:
    var start_x := fighter.movement_motor.sim_position.x
    for _i in range(4):
        var frame := battle.frame_number + 1
        _tick(battle, InputFrame.new(frame, 1, 0, 0, 0, 0) if not target_is_b else null, InputFrame.new(frame, 1, 0, 0, 0, 0) if target_is_b else null)
    var walk := absi(fighter.movement_motor.sim_position.x - start_x)
    fighter.state_machine.transition_to(FighterStateMachine.State.DASH_FORWARD)
    fighter.state_machine.dash_move_remaining = 1
    start_x = fighter.movement_motor.sim_position.x
    _tick(battle)
    var dash := absi(fighter.movement_motor.sim_position.x - start_x)
    fighter.state_machine.transition_to(FighterStateMachine.State.BACKSTEP)
    fighter.state_machine.dash_move_remaining = 1
    start_x = fighter.movement_motor.sim_position.x
    _tick(battle)
    return {"walk": walk, "dash": dash, "backstep": absi(fighter.movement_motor.sim_position.x - start_x)}

func _attack_timeline(battle: BattleSimulation, fighter: Fighter) -> Dictionary:
    var move := fighter.move_registry.get_move(MoveIds.STAND_HEAVY)
    fighter.move_runner.interrupt()
    fighter.move_runner.start_move(move)
    fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
    fighter.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    var elapsed := 0
    var first_active := -1
    var last_active := -1
    while fighter.move_runner.is_running() and elapsed < 120:
        _tick(battle)
        elapsed += 1
        if fighter.move_runner.is_running() and fighter.move_runner.phase() == &"ACTIVE":
            if first_active < 0:
                first_active = elapsed
            last_active = elapsed
    return {"first_active": first_active, "last_active": last_active, "completion": elapsed}

func _reaction_timing(status: StatusEffectData) -> Dictionary:
    var hit := _battle(generic, generic, 50000, 54000)
    if status != null:
        hit.fighter_b.statuses.apply(status)
    _start_active_move(hit.fighter_a, MoveIds.STAND_LIGHT)
    _tick(hit)
    var hitstun := hit.fighter_b.combatant.hitstun_remaining
    var block := _battle(generic, generic, 50000, 54000)
    if status != null:
        block.fighter_b.statuses.apply(status)
    _start_active_move(block.fighter_a, MoveIds.STAND_LIGHT)
    _tick(block, null, _guard(1))
    return {"hitstun": hitstun, "blockstun": block.fighter_b.combatant.blockstun_remaining}

func _test_ya_locomotion_only_floor_overlap_expiry_and_snapshot() -> void:
    var baseline := _battle(ya, generic)
    var base_motion := _measure_locomotion(baseline, baseline.fighter_b, true)
    var slowed := _battle(ya, generic, 50000, 60000)
    _spawn_ya_area(slowed, &"ya_wave_l3")
    _tick(slowed)
    var status := _ya_slow_l3()
    t.that(slowed.fighter_b.has_status(&"awkward_slow"), "YA Lv3 area applies Slow through real Area runtime")
    t.equal(slowed.fighter_b.statuses.movement_permille(&"walk"), 780, "YA strongest Slow walk multiplier respects 0.78 floor")
    t.equal(slowed.fighter_b.statuses.movement_permille(&"dash"), 740, "YA strongest Slow dash multiplier respects 0.74 floor")
    t.equal(slowed.fighter_b.statuses.movement_permille(&"backstep"), 740, "YA strongest Slow backstep multiplier respects 0.74 floor")
    var slow_motion := _measure_locomotion(slowed, slowed.fighter_b, true)
    t.equal(slow_motion["walk"], int(base_motion["walk"]) * 780 / 1000, "YA Slow changes real walk displacement only by authored multiplier")
    t.equal(slow_motion["dash"], int(base_motion["dash"]) * 740 / 1000, "YA Slow changes real dash displacement only by authored multiplier")
    t.equal(slow_motion["backstep"], int(base_motion["backstep"]) * 740 / 1000, "YA Slow changes real backstep displacement only by authored multiplier")
    t.that(int(slow_motion["walk"]) < int(base_motion["walk"]) and int(slow_motion["dash"]) < int(base_motion["dash"]), "YA strongest Slow is meaningful without removing locomotion")

    var overlap := _battle(ya, generic, 50000, 60000)
    _spawn_ya_area(overlap, &"ya_wave_l2")
    _spawn_ya_area(overlap, &"ya_wave_l3")
    _spawn_ya_area(overlap, &"ya_wave_l3")
    var area_count := 0
    for runtime: TemporaryEntityRuntime in overlap.temporary_entity_system.active_entities():
        if runtime.kind == TemporaryEntityRuntime.Kind.AREA:
            area_count += 1
    _tick(overlap)
    t.equal(area_count, 1, "YA repeated/overlapping zones retain one replacement-group area")
    t.equal(overlap.fighter_b.statuses.capture_state().size(), 1, "YA repeated/overlapping zones retain one Slow status")
    t.equal(overlap.fighter_b.statuses.movement_permille(&"walk"), status.walk_speed_permille, "YA overlap does not stack movement multipliers")

    var expiry := _battle(ya, generic)
    expiry.fighter_b.statuses.apply(status)
    for _i in range(status.duration_frames):
        _tick(expiry)
    t.that(not expiry.fighter_b.has_status(&"awkward_slow"), "YA Slow expires through authoritative status ticking")
    t.equal(expiry.fighter_b.statuses.movement_permille(&"walk"), 1000, "YA expiry restores exact normal movement multiplier")

    var snapshot_battle := _battle(ya, generic)
    snapshot_battle.fighter_b.statuses.apply(status)
    _tick(snapshot_battle)
    var remaining := snapshot_battle.fighter_b.status_remaining(&"awkward_slow")
    var snapshot := snapshot_battle.capture_state()
    var motion_a := _measure_locomotion(snapshot_battle, snapshot_battle.fighter_b, true)
    var hash_a := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "YA active Slow snapshot restores")
    t.equal(snapshot_battle.fighter_b.status_remaining(&"awkward_slow"), remaining, "YA snapshot restores Slow remaining frames")
    t.equal(_measure_locomotion(snapshot_battle, snapshot_battle.fighter_b, true), motion_a, "YA snapshot restores identical locomotion result")
    t.equal(snapshot_battle.state_signature(), hash_a, "YA snapshot restores canonical hash")

func _test_ya_attack_and_reaction_timing() -> void:
    var control := _battle(generic, generic)
    var slowed := _battle(generic, generic)
    slowed.fighter_a.statuses.apply(_ya_slow_l3())
    t.equal(_attack_timeline(slowed, slowed.fighter_a), _attack_timeline(control, control.fighter_a), "YA Slow leaves attack startup, active frames, and recovery bit-identical")
    t.equal(_reaction_timing(_ya_slow_l3()), _reaction_timing(null), "YA Slow leaves hitstun and blockstun bit-identical")

func _test_sauce_levels_and_locomotion_only() -> void:
    var expected := {
        &"sauce_shot_l1": [120, 860, 860, 860],
        &"sauce_shot_l2": [180, 820, 820, 820],
        &"sauce_shot_l3": [240, 780, 780, 780],
    }
    for move_id: StringName in expected:
        var battle := _battle(sauce, generic)
        var status := _apply_sauce_projectile(battle, move_id)
        var values: Array = expected[move_id]
        t.that(status != null and battle.fighter_b.has_status(&"sauce"), "%s applies Sticky through real Projectile runtime" % String(move_id))
        t.equal(status.duration_frames, values[0], "%s authors required Sticky duration" % String(move_id))
        t.equal(battle.fighter_b.statuses.remaining_frames(&"sauce"), int(values[0]), "%s real Sticky duration starts deterministically" % String(move_id))
        t.equal(battle.fighter_b.statuses.movement_permille(&"walk"), values[1], "%s real Sticky walk multiplier is authored" % String(move_id))
        t.equal(battle.fighter_b.statuses.movement_permille(&"dash"), values[2], "%s real Sticky dash multiplier is authored" % String(move_id))
        t.equal(battle.fighter_b.statuses.movement_permille(&"backstep"), values[3], "%s real Sticky backstep multiplier is authored" % String(move_id))
    var control := _battle(generic, generic)
    var sticky := _battle(generic, generic)
    sticky.fighter_a.statuses.apply(_sauce_status(&"sauce_shot_l3"))
    t.equal(_attack_timeline(sticky, sticky.fighter_a), _attack_timeline(control, control.fighter_a), "Sauce Sticky leaves attack startup, active frames, and recovery bit-identical")
    t.equal(_reaction_timing(_sauce_status(&"sauce_shot_l3")), _reaction_timing(null), "Sauce Sticky leaves hitstun and blockstun bit-identical")

func _test_sauce_extension_cap_expiry_and_cashout() -> void:
    var l3 := _sauce_status(&"sauce_shot_l3")
    var extension := _battle(sauce, generic, 50000, 54000)
    extension.fighter_b.statuses.apply(l3)
    _start_active_move(extension.fighter_a, MoveIds.CROUCH_LOW)
    _tick(extension)
    t.equal(extension.fighter_b.status_remaining(&"sauce"), 300, "Sauce real Low extension adds 60F once")
    t.that(extension.fighter_b.statuses.extended_once(&"sauce"), "Sauce first Low extension records canonical extended_once")
    extension.fighter_b.combatant.hitstop_remaining = 0
    extension.fighter_b.combatant.hitstun_remaining = 0
    extension.fighter_b.state_machine.transition_to(FighterStateMachine.State.IDLE)
    _start_active_move(extension.fighter_a, MoveIds.CROUCH_LOW)
    _tick(extension)
    t.equal(extension.fighter_b.status_remaining(&"sauce"), 299, "Sauce second Low extension adds zero frames")
    t.that(extension.fighter_b.status_remaining(&"sauce") <= 300, "Sauce Sticky remaining duration is bounded at 300F")
    extension.fighter_b.statuses.apply(l3)
    t.equal(extension.fighter_b.status_remaining(&"sauce"), 240, "Sauce refresh returns to authored duration rather than extending indefinitely")
    t.that(extension.fighter_b.statuses.extended_once(&"sauce"), "Sauce refresh retains one-extension lifecycle state")

    var expiry := _battle(sauce, generic)
    expiry.fighter_b.statuses.apply(_sauce_status(&"sauce_shot_l1"))
    for _i in range(120):
        _tick(expiry)
    t.that(not expiry.fighter_b.has_status(&"sauce"), "Sauce Sticky expires through authoritative status ticking")
    expiry.fighter_b.statuses.apply(_sauce_status(&"sauce_shot_l1"))
    t.that(not expiry.fighter_b.statuses.extended_once(&"sauce"), "New Sauce lifecycle resets extended_once")

    var no_sticky := _battle(sauce, generic, 50000, 60000)
    var with_sticky := _battle(sauce, generic, 50000, 60000)
    with_sticky.fighter_b.statuses.apply(l3)
    var ultimate := _move_from_set(sauce.move_set, MoveIds.ULTIMATE)
    no_sticky.combat_resolver.effect_executor.execute_all(ultimate.on_start_effects, no_sticky.fighter_a, no_sticky.fighter_b, no_sticky.temporary_entity_system, GameplayConditionEvaluator.contact_flags(no_sticky.fighter_b), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS)
    with_sticky.combat_resolver.effect_executor.execute_all(ultimate.on_start_effects, with_sticky.fighter_a, with_sticky.fighter_b, with_sticky.temporary_entity_system, GameplayConditionEvaluator.contact_flags(with_sticky.fighter_b), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS)
    var hp_no_sticky := no_sticky.fighter_b.combatant.hp
    var hp_with_sticky := with_sticky.fighter_b.combatant.hp
    for _i in range(123):
        _tick(no_sticky)
        _tick(with_sticky)
    var normal_damage := hp_no_sticky - no_sticky.fighter_b.combatant.hp
    var cashout_damage := hp_with_sticky - with_sticky.fighter_b.combatant.hp
    t.equal(cashout_damage - normal_damage, 45, "Sauce Sticky Ultimate retains its stronger 45-damage final cashout")
    t.that(not with_sticky.fighter_b.has_status(&"sauce"), "Sauce Sticky Ultimate consumes Sticky")
    t.that(no_sticky.fighter_b.combatant.hp < hp_no_sticky, "Sauce Ultimate remains functional without Sticky")

func _test_sauce_snapshot_hash_and_doge_sanity() -> void:
    var l3 := _sauce_status(&"sauce_shot_l3")
    var snapshot_battle := _battle(sauce, generic, 50000, 60000)
    snapshot_battle.fighter_b.statuses.apply(l3)
    t.that(snapshot_battle.fighter_b.statuses.extend_once(&"sauce", 60), "Sauce snapshot setup consumes first legal extension")
    var snapshot := snapshot_battle.capture_state()
    var ultimate := _move_from_set(sauce.move_set, MoveIds.ULTIMATE)
    snapshot_battle.combat_resolver.effect_executor.execute_all(ultimate.on_start_effects, snapshot_battle.fighter_a, snapshot_battle.fighter_b, snapshot_battle.temporary_entity_system, GameplayConditionEvaluator.contact_flags(snapshot_battle.fighter_b), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS)
    for _i in range(123):
        _tick(snapshot_battle)
    var hash_a := snapshot_battle.state_signature()
    var hp_a := snapshot_battle.fighter_b.combatant.hp
    t.that(snapshot_battle.restore_state(snapshot), "Sauce Sticky extended_once snapshot restores")
    t.that(snapshot_battle.fighter_b.statuses.extended_once(&"sauce"), "Sauce snapshot restores extension legality")
    snapshot_battle.combat_resolver.effect_executor.execute_all(ultimate.on_start_effects, snapshot_battle.fighter_a, snapshot_battle.fighter_b, snapshot_battle.temporary_entity_system, GameplayConditionEvaluator.contact_flags(snapshot_battle.fighter_b), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS)
    for _i in range(123):
        _tick(snapshot_battle)
    t.equal(snapshot_battle.fighter_b.combatant.hp, hp_a, "Sauce restored Sticky reproduces Ultimate consume result")
    t.equal(snapshot_battle.state_signature(), hash_a, "Sauce restored Sticky reproduces canonical hash")

    var doge_sanity := _battle(sauce, doge)
    var doge_before := _attack_timeline(doge_sanity, doge_sanity.fighter_b)
    doge_sanity.fighter_b.statuses.apply(l3)
    t.equal(doge_sanity.fighter_b.statuses.movement_permille(&"walk"), 780, "Sauce Lv3 Sticky applies authored locomotion multiplier to Doge")
    t.equal(_attack_timeline(doge_sanity, doge_sanity.fighter_b), doge_before, "Sauce Lv3 Sticky does not change Doge attack timing")
