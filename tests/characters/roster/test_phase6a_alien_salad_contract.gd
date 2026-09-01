# Phase 6A real-runtime positional-control contracts for Alien Meow and Salad Cat.
class_name Phase6AAlienSaladContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")

var t = ASSERT_HELPER.new()
var alien: CharacterData
var salad: CharacterData
var generic: CharacterData

func run_all() -> int:
    alien = RosterRegistry.character_by_id(&"alien_meow")
    salad = RosterRegistry.character_by_id(&"salad_cat")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_alien_unmarked_and_marked_position_lock()
    _test_alien_escape_and_snapshot_hash()
    _test_salad_near_far_never_pull_and_facing()
    _test_salad_corner_counter_heavy_and_ultimate()
    _test_salad_snapshot_hash_and_generic_outward_semantics()
    print("\nPhase 6A Alien/Salad contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData, ax: int = 50000, bx: int = 60000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(InputFrame.neutral(frame), InputFrame.neutral(frame))

func _sequence_from_move(move: MoveData, sequence_id: StringName) -> SequenceData:
    if move == null:
        return null
    for effect: GameplayEffectData in move.on_start_effects:
        if effect != null and effect.sequence != null and effect.sequence.id == sequence_id:
            return effect.sequence
    return null

func _sequence_runtime(battle: BattleSimulation, sequence_id: StringName) -> TemporaryEntityRuntime:
    for runtime: TemporaryEntityRuntime in battle.temporary_entity_system.active_entities():
        if runtime.kind == TemporaryEntityRuntime.Kind.SEQUENCE and runtime.data_id == sequence_id:
            return runtime
    return null

func _spawn_position_lock(battle: BattleSimulation) -> TemporaryEntityRuntime:
    var ultimate := battle.fighter_a.move_registry.get_move(MoveIds.ULTIMATE)
    var flags := GameplayConditionEvaluator.contact_flags(battle.fighter_b)
    battle.combat_resolver.effect_executor.execute_all(
        ultimate.on_start_effects,
        battle.fighter_a,
        battle.fighter_b,
        battle.temporary_entity_system,
        flags,
        BattleSimulation.STAGE_LEFT_UNITS,
        BattleSimulation.STAGE_RIGHT_UNITS
    )
    return _sequence_runtime(battle, &"alien_position_lock_marked") if battle.fighter_b.has_status(&"signal_mark") else _sequence_runtime(battle, &"alien_position_lock")

func _apply_signal_mark(battle: BattleSimulation) -> void:
    var scan := battle.fighter_a.move_registry.get_move(&"alien_scan_l3")
    battle.combat_resolver.effect_executor.execute_all(
        scan.on_hit_effects,
        battle.fighter_a,
        battle.fighter_b,
        battle.temporary_entity_system,
        GameplayConditionEvaluator.contact_flags(battle.fighter_b),
        BattleSimulation.STAGE_LEFT_UNITS,
        BattleSimulation.STAGE_RIGHT_UNITS
    )

func _frames_to_first_sequence_step(battle: BattleSimulation, sequence: TemporaryEntityRuntime) -> int:
    var frames := 0
    while sequence != null and (sequence.sequence_step_mask & 1) == 0 and frames < 120:
        _tick(battle)
        frames += 1
        sequence = _sequence_runtime(battle, sequence.data_id)
    return frames

func _test_alien_unmarked_and_marked_position_lock() -> void:
    var unmarked := _battle(alien, generic)
    unmarked.fighter_b.movement_motor.sim_position.x = 65000
    var sequence := _spawn_position_lock(unmarked)
    t.that(sequence != null, "Alien unmarked Ultimate spawns the unmarked Position Lock sequence")
    if sequence == null:
        return
    _tick(unmarked)
    var recorded: Vector2i = sequence.recorded_positions.get(0, Vector2i.ZERO)
    t.equal(recorded.x, 65000, "Alien unmarked Position Lock records the opponent coordinate")
    unmarked.fighter_b.movement_motor.sim_position.x = 90000
    for _i in range(25):
        _tick(unmarked)
    sequence = _sequence_runtime(unmarked, &"alien_position_lock")
    t.equal(sequence.recorded_positions.get(0, Vector2i.ZERO), recorded, "Alien unmarked blast remains fixed at the recorded coordinate")
    var unmarked_data := _sequence_from_move(unmarked.fighter_a.move_registry.get_move(MoveIds.ULTIMATE), &"alien_position_lock")
    t.equal(unmarked_data.steps[0].telegraph_frames, 24, "Alien unmarked warning is the authored 24F")
    var unmarked_warning := _battle(alien, generic)
    t.equal(_frames_to_first_sequence_step(unmarked_warning, _spawn_position_lock(unmarked_warning)), 24, "Alien unmarked warning executes for 24 simulation frames")

    var marked := _battle(alien, generic)
    _apply_signal_mark(marked)
    t.that(marked.fighter_b.statuses.has_status(&"signal_mark"), "Alien Scan applies Signal Mark through canonical StatusEffectComponent")
    marked.fighter_b.movement_motor.sim_position.x = 65500
    sequence = _spawn_position_lock(marked)
    t.that(sequence != null and sequence.data_id == &"alien_position_lock_marked", "Signal Mark selects the marked Position Lock sequence")
    if sequence == null:
        return
    _tick(marked)
    recorded = sequence.recorded_positions.get(0, Vector2i.ZERO)
    marked.fighter_b.movement_motor.sim_position.x = 91000
    for _i in range(25):
        _tick(marked)
    sequence = _sequence_runtime(marked, &"alien_position_lock_marked")
    t.equal(sequence.recorded_positions.get(0, Vector2i.ZERO), recorded, "Alien marked blast remains fixed at the recorded coordinate")
    var marked_data := _sequence_from_move(marked.fighter_a.move_registry.get_move(MoveIds.ULTIMATE), &"alien_position_lock_marked")
    t.equal(marked_data.steps[0].telegraph_frames, 13, "Alien marked warning is the authored 13F")
    var marked_warning := _battle(alien, generic)
    _apply_signal_mark(marked_warning)
    t.equal(_frames_to_first_sequence_step(marked_warning, _spawn_position_lock(marked_warning)), 13, "Alien marked warning executes for 13 simulation frames")

func _test_alien_escape_and_snapshot_hash() -> void:
    var escape := _battle(alien, generic)
    escape.fighter_b.movement_motor.sim_position.x = 65000
    var sequence := _spawn_position_lock(escape)
    _tick(escape)
    escape.fighter_b.movement_motor.sim_position.x = 90000
    var hp_before := escape.fighter_b.combatant.hp
    for _i in range(30):
        _tick(escape)
    t.equal(escape.fighter_b.combatant.hp, hp_before, "Alien defender can leave the recorded point before the blast")

    var deterministic := _battle(alien, generic)
    _apply_signal_mark(deterministic)
    deterministic.fighter_b.movement_motor.sim_position.x = 66000
    sequence = _spawn_position_lock(deterministic)
    _tick(deterministic)
    var recorded: Vector2i = sequence.recorded_positions.get(0, Vector2i.ZERO)
    var snapshot := deterministic.capture_state()
    for _i in range(30):
        _tick(deterministic)
    var hp_after := deterministic.fighter_b.combatant.hp
    var hash_after := deterministic.state_signature()
    t.that(deterministic.restore_state(snapshot), "Alien pending marked Position Lock snapshot restores")
    sequence = _sequence_runtime(deterministic, &"alien_position_lock_marked")
    t.equal(sequence.recorded_positions.get(0, Vector2i.ZERO), recorded, "Alien snapshot restores recorded coordinate")
    for _i in range(30):
        _tick(deterministic)
    t.equal(deterministic.fighter_b.combatant.hp, hp_after, "Alien restored Position Lock reproduces impact result")
    t.equal(deterministic.state_signature(), hash_after, "Alien restored Position Lock reproduces canonical hash")

func _start_active_move(fighter: Fighter, move_id: StringName) -> MoveData:
    var move := fighter.move_registry.get_move(move_id)
    fighter.move_runner.interrupt()
    if move != null:
        fighter.move_runner.start_move(move)
        fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
        fighter.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
        fighter.move_runner.move_frame = move.first_active_frame()
    return move

func _land_salad_low(battle: BattleSimulation, attacker: Fighter, defender: Fighter, separation: int) -> Dictionary:
    var sign := 1 if attacker.movement_motor.sim_position.x < defender.movement_motor.sim_position.x else -1
    defender.movement_motor.sim_position.x = attacker.movement_motor.sim_position.x + sign * separation
    var before := absi(defender.movement_motor.sim_position.x - attacker.movement_motor.sim_position.x)
    var hp_before := defender.combatant.hp
    _start_active_move(attacker, MoveIds.CROUCH_LOW)
    _tick(battle)
    return {
        "before": before,
        "after": absi(defender.movement_motor.sim_position.x - attacker.movement_motor.sim_position.x),
        "hit": defender.combatant.hp < hp_before,
    }

func _apply_salad_positioning(effect: GameplayEffectData, attacker: Fighter, defender: Fighter, battle: BattleSimulation) -> void:
    battle.combat_resolver.effect_executor.execute_all(
        [effect], attacker, defender, battle.temporary_entity_system,
        GameplayConditionEvaluator.contact_flags(defender), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS
    )

func _test_salad_near_far_never_pull_and_facing() -> void:
    var near_battle := _battle(salad, generic, 50000, 54000)
    var near := _land_salad_low(near_battle, near_battle.fighter_a, near_battle.fighter_b, 4000)
    t.that(bool(near["hit"]), "Salad near Low lands through real BattleSimulation collision")
    t.equal(near["after"], 19000, "Salad near Low establishes its authored 3.17u spacing")

    var far_battle := _battle(salad, generic, 50000, 60000)
    var far := _land_salad_low(far_battle, far_battle.fighter_a, far_battle.fighter_b, 10000)
    t.that(bool(far["hit"]), "Salad farther Low still lands through real BattleSimulation collision")
    t.that(int(far["after"]) - int(far["before"]) < int(near["after"]) - int(near["before"]), "Salad far hit displaces less than its near hit")

    var never_pull := _battle(salad, generic, 50000, 80000)
    var low := never_pull.fighter_a.move_registry.get_move(MoveIds.CROUCH_LOW)
    var effect: GameplayEffectData = low.on_hit_effects[0]
    var old_distance := absi(never_pull.fighter_b.movement_motor.sim_position.x - never_pull.fighter_a.movement_motor.sim_position.x)
    _apply_salad_positioning(effect, never_pull.fighter_a, never_pull.fighter_b, never_pull)
    var new_distance := absi(never_pull.fighter_b.movement_motor.sim_position.x - never_pull.fighter_a.movement_motor.sim_position.x)
    t.that(new_distance >= old_distance, "Salad outward spacing never pulls an already-far defender closer")
    var throw_positioning := never_pull.fighter_a.move_registry.get_move(MoveIds.GROUND_THROW).throw_positioning
    var ultimate_positioning: GameplayEffectData = never_pull.fighter_a.move_registry.get_move(MoveIds.ULTIMATE).on_complete_effects[0]
    for authored_effect: GameplayEffectData in [GameplayEffectData.new(), ultimate_positioning]:
        if authored_effect == null:
            continue
        if authored_effect == ultimate_positioning:
            _apply_salad_positioning(authored_effect, never_pull.fighter_a, never_pull.fighter_b, never_pull)
            t.that(absi(never_pull.fighter_b.movement_motor.sim_position.x - never_pull.fighter_a.movement_motor.sim_position.x) >= old_distance, "Salad Ultimate completion spacing never pulls an already-far defender")
        else:
            authored_effect.type = GameplayEffectData.Type.POSITION_EFFECT
            authored_effect.positioning = throw_positioning
            _apply_salad_positioning(authored_effect, never_pull.fighter_a, never_pull.fighter_b, never_pull)
            t.that(absi(never_pull.fighter_b.movement_motor.sim_position.x - never_pull.fighter_a.movement_motor.sim_position.x) >= old_distance, "Salad Throw spacing never pulls an already-far defender")

    var reversed := _battle(generic, salad, 50000, 54000)
    var reverse := _land_salad_low(reversed, reversed.fighter_b, reversed.fighter_a, 4000)
    t.that(bool(reverse["hit"]), "Salad Low lands while Salad is on the right side")
    t.equal(reverse["after"], 19000, "Salad outward spacing works under reversed facing")
    t.that(reversed.fighter_a.movement_motor.sim_position.x < reversed.fighter_b.movement_motor.sim_position.x, "Reversed-facing Salad pushes the defender away on the negative X side")

func _test_salad_corner_counter_heavy_and_ultimate() -> void:
    var corner := _battle(salad, generic, 105000, 112000)
    var result := _land_salad_low(corner, corner.fighter_a, corner.fighter_b, 7000)
    t.that(bool(result["hit"]), "Salad corner Low lands")
    t.equal(corner.fighter_b.movement_motor.sim_position.x, BattleSimulation.STAGE_RIGHT_UNITS, "Salad outward spacing clamps defender at the stage corner")
    t.that(corner.fighter_a.movement_motor.sim_position.x < corner.fighter_b.movement_motor.sim_position.x, "Salad corner spacing never reverses fighter order")
    t.that(int(result["after"]) >= int(result["before"]), "Salad corner spacing never pulls")

    var low := corner.fighter_a.move_registry.get_move(MoveIds.CROUCH_LOW)
    var heavy := corner.fighter_a.move_registry.get_move(MoveIds.STAND_HEAVY)
    t.that(low.counter_hit_reaction_type != CombatReaction.Type.NONE, "Salad authored counter-hit behavior remains present")
    t.equal(heavy.recovery_frames, 19, "Salad Heavy retains its authored 19F whiff recovery")

    var ultimate_battle := _battle(salad, generic)
    ultimate_battle.fighter_b.movement_motor.sim_position.x = 65000
    var ultimate := ultimate_battle.fighter_a.move_registry.get_move(MoveIds.ULTIMATE)
    ultimate_battle.combat_resolver.effect_executor.execute_all(
        ultimate.on_start_effects, ultimate_battle.fighter_a, ultimate_battle.fighter_b, ultimate_battle.temporary_entity_system,
        GameplayConditionEvaluator.contact_flags(ultimate_battle.fighter_b), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS
    )
    _tick(ultimate_battle)
    ultimate_battle.fighter_b.movement_motor.sim_position.x = 90000
    var hp_before := ultimate_battle.fighter_b.combatant.hp
    for _i in range(60):
        _tick(ultimate_battle)
    t.equal(ultimate_battle.fighter_b.combatant.hp, hp_before, "Salad Ultimate retains movement escape counterplay after recorded acquisition")

func _test_salad_snapshot_hash_and_generic_outward_semantics() -> void:
    var battle := _battle(salad, generic, 50000, 54000)
    var low := battle.fighter_a.move_registry.get_move(MoveIds.CROUCH_LOW)
    var snapshot := battle.capture_state()
    _apply_salad_positioning(low.on_hit_effects[0], battle.fighter_a, battle.fighter_b, battle)
    var first_position := battle.fighter_b.movement_motor.sim_position
    var first_hash := battle.state_signature()
    t.that(battle.restore_state(snapshot), "Salad positioning snapshot restores")
    _apply_salad_positioning(low.on_hit_effects[0], battle.fighter_a, battle.fighter_b, battle)
    t.equal(battle.fighter_b.movement_motor.sim_position, first_position, "Salad restored spacing reproduces final position")
    t.equal(battle.state_signature(), first_hash, "Salad restored spacing reproduces canonical hash")

    var system := PositioningSystem.new()
    var effect := PositioningEffectData.new()
    effect.type = PositioningEffectData.Type.PUSH_TO_MINIMUM_SEPARATION
    effect.distance_units = 19000
    var left := _battle(generic, generic, 50000, 55000)
    system.apply(effect, left.fighter_a, left.fighter_b, BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS)
    t.equal(left.fighter_b.movement_motor.sim_position.x - left.fighter_a.movement_motor.sim_position.x, 19000, "Generic minimum-separation pushes right-side defender outward")
    var right := _battle(generic, generic, 55000, 50000)
    system.apply(effect, right.fighter_a, right.fighter_b, BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS)
    t.equal(right.fighter_a.movement_motor.sim_position.x - right.fighter_b.movement_motor.sim_position.x, 19000, "Generic minimum-separation pushes left-side defender outward")
