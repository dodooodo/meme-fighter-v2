# Responsibility: M2.3 Air Combat regression suite.
# Owns: tests only. Does NOT own production behavior or presentation.
# Dependencies: BattleSimulation, InputHistory/Parser, Air MoveData, CombatResolver.
class_name Milestone23AirTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_up_edge_and_integer_jump_arc()
    _test_same_frame_jump_attack_buffers_into_air_attack()
    _test_air_light_heavy_map_same_move_and_one_per_jump()
    _test_air_guard_matrix_high()
    _test_stage_clamp_cross_over_and_facing_timing()
    _test_attack_facing_lock()
    _test_vertical_knockback_and_airborne_hitstun()
    _test_hitstop_preserves_vertical_velocity()
    _test_airborne_ko_falls_to_ground()
    _test_ground_pushbox_regression()
    print("\nM2.3 Air Combat tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 40000, p2_x: int = 100000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(character, character, null, null, Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS), Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _frame(frame: int, x: int = 0, y: int = 0, held: int = 0, pressed: int = 0) -> InputFrame:
    return InputFrame.new(frame, x, y, held, pressed, 0)

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _test_up_edge_and_integer_jump_arc() -> void:
    var battle := _battle()
    _tick(battle, _frame(1, 0, 1))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.JUMP, "Up edge starts Jump")
    t.equal(battle.fighter_a.movement_motor.sim_position.y, BattleSimulation.GROUND_Y_UNITS - 1400, "Jump first tick uses integer vertical integration")
    var velocity_after_first := battle.fighter_a.movement_motor.velocity_units.y
    _tick(battle, _frame(2, 0, 1))
    t.that(battle.fighter_a.movement_motor.velocity_units.y != character.jump_velocity_y_units_per_tick, "Holding Up does not retrigger Jump every frame")
    t.that(battle.fighter_a.movement_motor.velocity_units.y > velocity_after_first, "Gravity advances integer vertical velocity toward apex")

    var saw_apex := false
    var saw_fall := false
    for _i in range(80):
        var previous_velocity := battle.fighter_a.movement_motor.velocity_units.y
        _tick(battle)
        if previous_velocity < 0 and battle.fighter_a.movement_motor.velocity_units.y >= 0:
            saw_apex = true
        if saw_apex and battle.fighter_a.movement_motor.velocity_units.y > 0:
            saw_fall = true
        if battle.fighter_a.state_machine.state == FighterStateMachine.State.LANDING:
            break
    t.that(saw_apex, "Jump reaches apex")
    t.that(saw_fall, "Jump falls after apex")
    t.equal(battle.fighter_a.movement_motor.sim_position.y, BattleSimulation.GROUND_Y_UNITS, "Landing snaps exactly to ground_y")
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.LANDING, "Landing enters LANDING state")
    t.equal(battle.fighter_a.state_machine.landing_remaining, character.landing_recovery_frames, "Landing recovery starts at configured 3F")

func _test_same_frame_jump_attack_buffers_into_air_attack() -> void:
    var battle := _battle()
    var light := InputFrame.InputButton.LIGHT
    _tick(battle, _frame(1, 0, 1, light, light))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.JUMP, "Jump has movement-state priority over same-frame Light")
    t.that(battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Same-frame Jump+Light preserves ActionIntent in 5F buffer")
    _tick(battle)
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.AIR_ATTACK, "Buffered Light starts Air Attack on next airborne tick")
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.AIR_ATTACK, "Air Light starts AIR_ATTACK")

func _test_air_light_heavy_map_same_move_and_one_per_jump() -> void:
    var registry := MoveRegistry.new()
    registry.configure(character.move_set)
    var air := registry.get_move(MoveIds.AIR_ATTACK)
    t.equal(air.startup_frames, 6, "Air Attack startup is 6F")
    t.equal(air.active_frames, 4, "Air Attack active is 4F")
    t.equal(air.recovery_frames, 12, "Air Attack recovery is 12F")
    t.equal(air.damage, 70, "Air Attack damage is 70")
    t.equal(air.hit_level, MoveData.HitLevel.HIGH, "Air Attack HitLevel = HIGH")
    t.equal(air.knockback_y_units, -350, "Air Attack carries vertical knockback")

    for button in [InputFrame.InputButton.LIGHT, InputFrame.InputButton.HEAVY]:
        var battle := _battle()
        _tick(battle, _frame(1, 0, 1))
        _tick(battle, _frame(2, 0, 0, button, button))
        t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.AIR_ATTACK, "Air Light/Heavy both map to same AIR_ATTACK")

    var once := _battle()
    _tick(once, _frame(1, 0, 1))
    var light := InputFrame.InputButton.LIGHT
    _tick(once, _frame(2, 0, 0, light, light))
    while once.fighter_a.move_runner.is_running() and once.fighter_a.movement_motor.is_airborne():
        _tick(once)
    t.that(once.fighter_a.movement_motor.is_airborne(), "Air Attack recovery can finish while still airborne")
    t.equal(once.fighter_a.state_machine.state, FighterStateMachine.State.JUMP, "Air Attack returns to Jump if recovery ends airborne")
    t.that(not once.fighter_a.state_machine.air_attack_available, "Air Attack consumes once-per-jump availability")
    var heavy := InputFrame.InputButton.HEAVY
    _tick(once, _frame(once.frame_number + 1, 0, 0, heavy, heavy))
    t.that(not once.fighter_a.move_runner.is_running(), "Second Air Attack is rejected in same jump")
    while once.fighter_a.state_machine.state != FighterStateMachine.State.LANDING and once.frame_number < 100:
        _tick(once)
    t.that(once.fighter_a.state_machine.air_attack_available, "Landing resets air attack availability")

func _test_air_guard_matrix_high() -> void:
    var battle := _battle(50000, 58000)
    var contact := StrikeContact.new()
    contact.attacker_id = 1
    contact.defender_id = 2
    contact.move_id = MoveIds.AIR_ATTACK
    contact.attack_instance_id = 123
    contact.incoming_direction_x = battle.fighter_b.movement_motor.facing
    battle.fighter_b.state_machine.state = FighterStateMachine.State.GUARD
    battle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.GROUNDED
    battle.fighter_b.state_machine.guard_posture = FighterStateMachine.GuardPosture.STANDING
    var standing := battle.combat_resolver.resolve_strike_contact(contact, battle.fighter_a, battle.fighter_b)
    t.equal(standing.result_type, HitResult.ResultType.BLOCK, "Standing Guard blocks HIGH Air Attack")
    battle.fighter_b.state_machine.guard_posture = FighterStateMachine.GuardPosture.CROUCHING
    var crouching := battle.combat_resolver.resolve_strike_contact(contact, battle.fighter_a, battle.fighter_b)
    t.equal(crouching.result_type, HitResult.ResultType.HIT, "Crouching Guard loses to HIGH Air Attack")

func _test_stage_clamp_cross_over_and_facing_timing() -> void:
    var edge := _battle(BattleSimulation.STAGE_RIGHT_UNITS - 100, 20000)
    edge.fighter_a.movement_motor.facing = 1
    _tick(edge, _frame(1, 1, 1))
    t.equal(edge.fighter_a.movement_motor.sim_position.x, BattleSimulation.STAGE_RIGHT_UNITS, "Stage X clamp works in air without forcing Y to ground")
    t.that(edge.fighter_a.movement_motor.is_airborne(), "Stage X clamp preserves airborne Y")

    var cross := _battle(50000, 50600)
    _tick(cross, _frame(1, 1, 1))
    _tick(cross, _frame(2, 1, 0))
    t.equal(cross.fighter_a.movement_motor.facing, 1, "Facing remains right before cross-over")
    _tick(cross, _frame(3, 1, 0))
    t.that(cross.fighter_a.movement_motor.sim_position.x > cross.fighter_b.movement_motor.sim_position.x, "Airborne fighter can cross opponent because pushbox separation is skipped")
    t.equal(cross.fighter_a.movement_motor.facing, -1, "Cross-over updates stored facing at end of tick")
    t.that(cross.fighter_a.input_parser.forward_held, "Cross-over tick parsing still used tick-start facing")
    _tick(cross, _frame(4, 1, 0))
    t.that(cross.fighter_a.input_parser.back_held, "New facing affects relative direction on next simulation tick")

func _test_attack_facing_lock() -> void:
    var battle := _battle(50000, 70000)
    _tick(battle, _frame(1, 0, 1))
    var light := InputFrame.InputButton.LIGHT
    _tick(battle, _frame(2, 0, 0, light, light))
    var locked_facing := battle.fighter_a.movement_motor.facing
    battle.fighter_b.movement_motor.sim_position.x = 40000
    _tick(battle)
    t.equal(battle.fighter_a.movement_motor.facing, locked_facing, "Attack facing does not flip during running AIR_ATTACK")

func _test_vertical_knockback_and_airborne_hitstun() -> void:
    var battle := _battle()
    battle.fighter_a.combatant.receive_hit(0, 10, 0, 0, -350)
    battle.fighter_a.state_machine.transition_to(FighterStateMachine.State.HITSTUN)
    var start_y := battle.fighter_a.movement_motor.sim_position.y
    _tick(battle)
    t.that(battle.fighter_a.movement_motor.sim_position.y < start_y, "Vertical knockback applies and launches grounded defender")
    var y_after_launch := battle.fighter_a.movement_motor.sim_position.y
    _tick(battle)
    t.that(battle.fighter_a.movement_motor.sim_position.y != y_after_launch, "Airborne Hitstun moves vertically under deterministic gravity")

func _test_hitstop_preserves_vertical_velocity() -> void:
    var battle := _battle()
    _tick(battle, _frame(1, 0, 1))
    var velocity_before := battle.fighter_a.movement_motor.velocity_units
    var position_before := battle.fighter_a.movement_motor.sim_position
    battle.fighter_a.combatant.hitstop_remaining = 2
    _tick(battle)
    t.equal(battle.fighter_a.movement_motor.velocity_units, velocity_before, "Hitstop preserves vertical velocity instead of zeroing it")
    t.equal(battle.fighter_a.movement_motor.sim_position, position_before, "Hitstop freezes air integration")

func _test_airborne_ko_falls_to_ground() -> void:
    var battle := _battle()
    _tick(battle, _frame(1, 0, 1))
    _tick(battle)
    battle.fighter_a.combatant.hp = 0
    battle.fighter_a.combatant.is_ko = true
    for _i in range(100):
        _tick(battle)
        if not battle.fighter_a.movement_motor.is_airborne():
            break
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.KO, "KO overrides airborne control")
    t.equal(battle.fighter_a.movement_motor.sim_position.y, BattleSimulation.GROUND_Y_UNITS, "KO airborne fighter eventually falls to ground")

func _test_ground_pushbox_regression() -> void:
    var battle := _battle(50000, 52000)
    _tick(battle)
    var a_rect := battle.fighter_a.hitbox_owner.pushbox_rect(battle.fighter_a.position_pixels(), battle.fighter_a.movement_motor.facing)
    var b_rect := battle.fighter_b.hitbox_owner.pushbox_rect(battle.fighter_b.position_pixels(), battle.fighter_b.movement_motor.facing)
    t.that(not a_rect.intersects(b_rect), "Ground pushbox regression remains preserved")
