# Responsibility: M8A deterministic CPU InputSource and match wiring regression tests.
class_name M8CpuInputSourceTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData

func run_all() -> int:
    generic = RosterRegistry.character_by_id(&"alien_meow")
    _test_match_mode_input_wiring()
    _test_canonical_frame_and_bits()
    _test_guard_throw_and_ultimate_are_inputs_only()
    _test_reaction_block_and_crouch_behavior()
    _test_deterministic_sequence_and_reset()
    _test_round_reset_preserves_cpu_binding()
    _test_short_deterministic_stress()
    print("\nM8A CPU InputSource tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _cpu_battle(seed: int = 4242) -> Dictionary:
    var cpu := CpuInputSource.new()
    cpu.set_fixed_seed(seed)
    var battle := BattleSimulation.new()
    battle.configure(generic, generic, null, cpu, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(78000, BattleSimulation.GROUND_Y_UNITS))
    t.that(cpu.bind_context(battle.fighter_b, battle.fighter_a, battle), "CPU context binds to existing Fighters/Simulation read-only view")
    return {"battle": battle, "cpu": cpu}

func _test_match_mode_input_wiring() -> void:
    t.that(BattleInputWiring.create_p1_source() is KeyboardInputSource, "P1 remains KeyboardInputSource")
    t.that(BattleInputWiring.create_p2_source(BattleMode.Mode.LOCAL_2P) is KeyboardInputSource, "LOCAL_2P P2 remains KeyboardInputSource")
    t.that(BattleInputWiring.create_p2_source(BattleMode.Mode.VS_CPU) is CpuInputSource, "VS_CPU P2 uses CpuInputSource")

func _test_canonical_frame_and_bits() -> void:
    var setup := _cpu_battle()
    var cpu := setup["cpu"] as CpuInputSource
    var legal_mask := InputFrame.InputButton.LIGHT | InputFrame.InputButton.HEAVY | InputFrame.InputButton.GUARD | InputFrame.InputButton.SPECIAL | InputFrame.InputButton.ULTIMATE
    for frame in range(1, 161):
        var input := cpu.sample(frame)
        t.equal(input.frame_number, frame, "CPU sample preserves requested frame number")
        t.that(input.direction_x >= -1 and input.direction_x <= 1, "CPU direction_x is canonical")
        t.that(input.direction_y >= -1 and input.direction_y <= 1, "CPU direction_y is canonical")
        t.equal(input.held_bits & ~legal_mask, 0, "CPU held bits contain no nonexistent buttons")
        t.equal(input.pressed_bits & ~legal_mask, 0, "CPU pressed bits contain no nonexistent buttons")
        t.equal(input.released_bits & ~legal_mask, 0, "CPU released bits contain no nonexistent buttons")

func _test_guard_throw_and_ultimate_are_inputs_only() -> void:
    var setup := _cpu_battle()
    var battle := setup["battle"] as BattleSimulation
    var cpu := setup["cpu"] as CpuInputSource
    var guard := cpu._frame_for_decision(1, 0, &"guard")
    t.that(guard.is_held(InputFrame.InputButton.GUARD), "CPU Guard uses canonical GUARD held bit")
    var throw_input := cpu._frame_for_decision(9, 0, &"throw")
    t.that(throw_input.is_pressed(InputFrame.InputButton.HEAVY), "CPU Throw uses HEAVY press")
    t.equal(throw_input.direction_x, battle.fighter_b.movement_motor.facing, "CPU Throw uses facing-relative Forward + Heavy")
    var ultimate_without_meter := cpu._frame_for_decision(17, 0, &"ultimate")
    t.that(not ultimate_without_meter.is_held(InputFrame.InputButton.ULTIMATE), "CPU cannot emit Ultimate action when authoritative meter is insufficient")
    battle.fighter_b.meter.gain(100)
    cpu.reset()
    var ultimate_with_meter := cpu._frame_for_decision(25, 0, &"ultimate")
    t.that(ultimate_with_meter.is_pressed(InputFrame.InputButton.ULTIMATE), "CPU with sufficient meter expresses Ultimate only through canonical input")


func _test_reaction_block_and_crouch_behavior() -> void:
    var setup := _cpu_battle(5150)
    var battle := setup["battle"] as BattleSimulation
    var cpu := setup["cpu"] as CpuInputSource
    var crouch := cpu._frame_for_decision(1, 0, &"crouch")
    t.equal(crouch.direction_y, -1, "CPU has a canonical plain crouch behavior through direction_y only")
    t.equal(crouch.held_bits, 0, "Plain crouch does not invent a Crouch button bit")

    cpu.reset()
    var first := cpu.sample(1)
    var locked_decision := cpu._current_decision
    battle.fighter_a.move_runner.start_move(battle.fighter_a.move_registry.get_move(MoveIds.STAND_HEAVY))
    var mid_block := cpu.sample(4)
    t.equal(cpu._current_decision, locked_decision, "CPU decision remains locked inside the 8F reaction block despite newly established opponent attack state")
    t.equal(first.frame_number, 1, "Reaction-lock setup samples canonical first frame")
    t.equal(mid_block.frame_number, 4, "Reaction-lock continuation preserves requested simulation frame")

func _test_deterministic_sequence_and_reset() -> void:
    var a := _cpu_battle(777)
    var b := _cpu_battle(777)
    var seq_a: Array[String] = []
    var seq_b: Array[String] = []
    for frame in range(1, 257):
        var ia := (a["cpu"] as CpuInputSource).sample(frame)
        var ib := (b["cpu"] as CpuInputSource).sample(frame)
        seq_a.append(_input_key(ia))
        seq_b.append(_input_key(ib))
    t.equal(seq_a, seq_b, "Same context/frame/seed produces identical CPU InputFrame sequence")
    (a["cpu"] as CpuInputSource).reset()
    var first_after_reset := (a["cpu"] as CpuInputSource).sample(1)
    var fresh := _cpu_battle(777)
    var fresh_first := (fresh["cpu"] as CpuInputSource).sample(1)
    t.equal(_input_key(first_after_reset), _input_key(fresh_first), "CpuInputSource.reset clears edge state deterministically")

func _test_round_reset_preserves_cpu_binding() -> void:
    var setup := _cpu_battle(991)
    var battle := setup["battle"] as BattleSimulation
    var cpu := setup["cpu"] as CpuInputSource
    battle.sample_and_simulate_frame()
    battle.reset_full_match()
    var input := cpu.sample(1)
    t.equal(input.frame_number, 1, "Full match reset keeps CpuInputSource context binding alive")

func _test_short_deterministic_stress() -> void:
    var setup := _cpu_battle(12345)
    var battle := setup["battle"] as BattleSimulation
    var valid := true
    var failure_reason := ""
    for _i in range(10000):
        battle.sample_and_simulate_frame()
        if battle.fighter_a.combatant.hp < 0 or battle.fighter_b.combatant.hp < 0:
            valid = false
            failure_reason = "HP underflow"
            break
        if battle.fighter_a.meter.get_value() < 0 or battle.fighter_a.meter.get_value() > 100 or battle.fighter_b.meter.get_value() < 0 or battle.fighter_b.meter.get_value() > 100:
            valid = false
            failure_reason = "meter outside 0..100"
            break
        if battle.fighter_a.move_runner.current_move != null and battle.fighter_a.move_registry.get_move(battle.fighter_a.move_runner.current_move_id()) == null:
            valid = false
            failure_reason = "invalid P1 Move ID"
            break
        if battle.fighter_b.move_runner.current_move != null and battle.fighter_b.move_registry.get_move(battle.fighter_b.move_runner.current_move_id()) == null:
            valid = false
            failure_reason = "invalid P2 Move ID"
            break
        if battle.fighter_a.move_runner.instance_serial() < 0 or battle.fighter_b.move_runner.instance_serial() < 0:
            valid = false
            failure_reason = "negative AttackInstance serial"
            break
        for projectile: ProjectileRuntime in battle.projectile_system.active_projectiles():
            if projectile == null or projectile.instance_id <= 0 or projectile.owner_fighter_id not in [1, 2]:
                valid = false
                failure_reason = "invalid projectile owner/runtime identity"
                break
        if not valid:
            break
        if battle.projectile_system.next_projectile_instance_serial < ProjectileSystem.INITIAL_INSTANCE_SERIAL:
            valid = false
            failure_reason = "invalid projectile serial"
            break
        if battle.round_controller.is_match_over():
            battle.reset_full_match()
    t.that(valid, "CPU deterministic 10000F stress remains valid: %s" % failure_reason)
    t.that(battle.frame_number >= 0, "CPU stress completes without invalid simulation frame")

func _input_key(input: InputFrame) -> String:
    return "%d:%d:%d:%d:%d:%d" % [input.frame_number, input.direction_x, input.direction_y, input.held_bits, input.pressed_bits, input.released_bits]
