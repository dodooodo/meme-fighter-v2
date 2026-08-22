# Responsibility: M2.2 crouch/guard/strike-outcome/blockstun regression suite.
# Owns: M2.2 tests only.
# Does NOT own: production combat behavior or presentation.
# Dependencies: BattleSimulation, StrikeContact, CombatResolver, MoveData, ActionIntent.
class_name Milestone22Tests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_crouch_state_and_movement()
    _test_contextual_normal_mapping()
    _test_crouch_low_data_and_registry()
    _test_crouch_low_startup_hit_duplicate_and_recovery()
    _test_buffered_down_light_stays_low_after_release()
    _test_guard_transitions_and_priority()
    _test_guard_hit_level_matrix_and_front_back()
    _test_real_light_and_heavy_block()
    _test_standing_guard_loses_to_real_low()
    _test_crouching_guard_blocks_real_low()
    _test_block_duplicate_contact_protection()
    _test_blockstun_state_and_ground_settle()
    _test_buffer_during_blockstun()
    _test_block_hitstop_freezes_move_timeline()
    _test_block_event_contract()
    print("\nM2.2 Ground Defense & Strike Outcome tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 50000, p2_x: int = 58000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        character,
        character,
        null,
        null,
        Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS)
    )
    return battle

func _neutral(frame: int, dir_x: int = 0, dir_y: int = 0) -> InputFrame:
    return InputFrame.new(frame, dir_x, dir_y, 0, 0, 0)

func _guard(frame: int, down: bool = false, pressed: bool = false) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, -1 if down else 0, bit, bit if pressed else 0, 0)

func _guard_and_light(frame: int, down: bool = false) -> InputFrame:
    var bits := InputFrame.InputButton.GUARD | InputFrame.InputButton.LIGHT
    return InputFrame.new(frame, 0, -1 if down else 0, bits, bits, 0)

func _light(frame: int, down: bool = false) -> InputFrame:
    return InputFrame.with_light_press(frame, 0, -1 if down else 0)

func _heavy(frame: int, down: bool = false) -> InputFrame:
    return InputFrame.with_heavy_press(frame, 0, -1 if down else 0)

func _tick_neutral(battle: BattleSimulation, count: int) -> void:
    for _i in range(count):
        var frame := battle.frame_number + 1
        battle.simulate_frame(_neutral(frame), _neutral(frame))

func _advance_p1_to_move_frame(battle: BattleSimulation, target_move_frame: int) -> void:
    while battle.fighter_a.move_runner.is_running() and battle.fighter_a.move_runner.move_frame < target_move_frame:
        _tick_neutral(battle, 1)

func _registry() -> MoveRegistry:
    var registry := MoveRegistry.new()
    registry.configure(character.move_set)
    return registry

func _count_events(events: Array[CombatEvent], event_type: int) -> int:
    var count := 0
    for event in events:
        if event.type == event_type:
            count += 1
    return count

func _test_crouch_state_and_movement() -> void:
    var battle := _battle(40000, 100000)
    var frame := 1
    battle.simulate_frame(_neutral(frame, 0, -1), _neutral(frame))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CROUCH, "Down held from Idle enters CROUCH")

    frame = 2
    battle.simulate_frame(_neutral(frame), _neutral(frame))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Release Down returns CROUCH to IDLE")

    var start_x := battle.fighter_a.movement_motor.sim_position.x
    frame = 3
    battle.simulate_frame(_neutral(frame, 1, -1), _neutral(frame))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CROUCH, "Down has grounded posture priority over horizontal walk")
    t.equal(battle.fighter_a.movement_motor.sim_position.x, start_x, "CROUCH has no horizontal walk movement")

func _test_contextual_normal_mapping() -> void:
    var neutral_light := ActionIntent.new(InputFrame.InputButton.LIGHT, 10, 0, 0, 1)
    var down_light := ActionIntent.new(InputFrame.InputButton.LIGHT, 11, 0, -1, 1)
    var down_heavy := ActionIntent.new(InputFrame.InputButton.HEAVY, 12, 0, -1, 1)
    t.equal(NormalAttackMoveMap.move_id_for_intent(neutral_light), MoveIds.STAND_LIGHT, "Neutral+Light maps to STAND_LIGHT")
    t.equal(NormalAttackMoveMap.move_id_for_intent(down_light), MoveIds.CROUCH_LOW, "Request-frame Down+Light maps to CROUCH_LOW")
    t.equal(NormalAttackMoveMap.move_id_for_intent(down_heavy), MoveIds.STAND_HEAVY, "Down+Heavy remains STAND_HEAVY")

func _test_crouch_low_data_and_registry() -> void:
    var registry := _registry()
    t.that(registry.has_move(MoveIds.CROUCH_LOW), "Generic Fighter MoveSet contains CROUCH_LOW")
    var low := registry.get_move(MoveIds.CROUCH_LOW)
    t.equal(low.startup_frames, 8, "Crouch Low startup is 8F")
    t.equal(low.active_frames, 3, "Crouch Low active is 3F")
    t.equal(low.recovery_frames, 16, "Crouch Low recovery is 16F")
    t.equal(low.total_frames(), 27, "Crouch Low frame 28 is actionable")
    t.equal(low.first_active_frame(), 9, "Crouch Low first active frame is 9")
    t.equal(low.damage, 60, "Crouch Low damage is 60")
    t.equal(low.hitstun_frames, 15, "Crouch Low hitstun is 15F")
    t.equal(low.blockstun_frames, 11, "Crouch Low blockstun is 11F")
    t.equal(low.hitstop_attacker, 4, "Crouch Low attacker hitstop is 4F")
    t.equal(low.hitstop_defender, 4, "Crouch Low defender hitstop is 4F")
    t.equal(low.hit_level, MoveData.HitLevel.LOW, "Crouch Low HitLevel is typed LOW")
    t.equal(low.knockback_x_units, 600, "Crouch Low horizontal knockback is 600 units")
    t.equal(low.knockback_y_units, 0, "Crouch Low has no vertical knockback")
    t.equal(low.hitbox.offset, Vector2(68, -38), "Crouch Low hitbox uses low vertical offset")
    t.equal(low.hitbox.size, Vector2(92, 36), "Crouch Low hitbox size matches prototype")

func _test_crouch_low_startup_hit_duplicate_and_recovery() -> void:
    var battle := _battle()
    battle.simulate_frame(_light(1, true), _neutral(1))
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.CROUCH_LOW, "Down+Light starts Crouch Low")
    _tick_neutral(battle, 7)
    t.equal(battle.fighter_b.combatant.hp, 1000, "Crouch Low cannot hit during startup frames 1-8")
    _tick_neutral(battle, 1)
    t.equal(battle.fighter_b.combatant.hp, 940, "Crouch Low hits for 60 on first Active frame 9")
    var hp_after_first := battle.fighter_b.combatant.hp
    _tick_neutral(battle, 9)
    t.equal(battle.fighter_b.combatant.hp, hp_after_first, "Crouch Low same AttackInstance cannot damage repeatedly across Active overlap")

    var far_battle := _battle(40000, 100000)
    far_battle.simulate_frame(_light(1, true), _neutral(1))
    _tick_neutral(far_battle, 26)
    t.that(not far_battle.fighter_a.move_runner.is_running(), "Crouch Low completes after frame 27")
    t.equal(far_battle.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Crouch Low recovery returns to valid grounded Idle when Down is released")

func _test_buffered_down_light_stays_low_after_release() -> void:
    var battle := _battle(40000, 100000)
    battle.simulate_frame(_light(1), _neutral(1))
    _advance_p1_to_move_frame(battle, 16)
    var request_frame := battle.frame_number + 1
    battle.simulate_frame(_light(request_frame, true), _neutral(request_frame))
    var buffered := battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(buffered != null and buffered.direction_y == -1, "Recovery buffers Down+Light request-frame context")
    _tick_neutral(battle, 3)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.CROUCH_LOW, "Buffered Down+Light remains CROUCH_LOW after Down is released")

func _test_guard_transitions_and_priority() -> void:
    var battle := _battle(40000, 100000)
    battle.simulate_frame(_guard(1, false, true), _neutral(1))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.GUARD, "Guard held enters GUARD")
    t.equal(battle.fighter_a.state_machine.guard_posture, FighterStateMachine.GuardPosture.STANDING, "Guard without Down is STANDING")

    battle.simulate_frame(_neutral(2), _neutral(2))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Release Guard with no Down returns to IDLE")

    battle.simulate_frame(_guard(3, true, true), _neutral(3))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.GUARD, "Down+Guard enters GUARD")
    t.equal(battle.fighter_a.state_machine.guard_posture, FighterStateMachine.GuardPosture.CROUCHING, "Down+Guard uses CROUCHING posture")

    battle.simulate_frame(_neutral(4, 0, -1), _neutral(4))
    t.equal(battle.fighter_a.state_machine.state, FighterStateMachine.State.CROUCH, "Release Guard while Down remains returns to CROUCH")

    var priority := _battle(40000, 100000)
    priority.simulate_frame(_guard_and_light(1), _neutral(1))
    t.equal(priority.fighter_a.state_machine.state, FighterStateMachine.State.GUARD, "Voluntary Guard has priority over simultaneous Light")
    t.that(priority.fighter_a.input_buffer.has_pending(priority.frame_number), "Simultaneous Light remains buffered while Guard is held")
    priority.simulate_frame(_neutral(2), _neutral(2))
    t.equal(priority.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Releasing Guard consumes still-valid buffered Light")

    var attack_lock := _battle(40000, 100000)
    attack_lock.simulate_frame(_light(1), _neutral(1))
    attack_lock.simulate_frame(_guard(2, false, true), _neutral(2))
    t.equal(attack_lock.fighter_a.state_machine.state, FighterStateMachine.State.GROUND_ATTACK, "Running GroundAttack cannot freely transition into Guard")

func _synthetic_outcome(hit_level: int, posture: int, front: bool) -> HitResult:
    var battle := _battle(40000, 100000)
    var move := MoveData.new()
    move.id = &"synthetic_guard_test"
    move.damage = 77
    move.hitstun_frames = 9
    move.blockstun_frames = 7
    move.hitstop_attacker = 3
    move.hitstop_defender = 3
    move.hit_level = hit_level
    var move_set := MoveSetData.new()
    move_set.moves.append(move)
    battle.fighter_a.move_registry.configure(move_set)
    battle.fighter_b.state_machine.state = FighterStateMachine.State.GUARD
    battle.fighter_b.state_machine.root_state = FighterStateMachine.RootState.GROUNDED
    battle.fighter_b.state_machine.guard_posture = posture
    var contact := StrikeContact.new()
    contact.attacker_id = 1
    contact.defender_id = 2
    contact.move_id = move.id
    contact.attack_instance_id = 1000001
    contact.hit_id = 0
    contact.hit_position = Vector2(540, 500)
    contact.incoming_direction_x = battle.fighter_b.movement_motor.facing if front else -battle.fighter_b.movement_motor.facing
    return battle.combat_resolver.resolve_strike_contact(contact, battle.fighter_a, battle.fighter_b)

func _test_guard_hit_level_matrix_and_front_back() -> void:
    t.equal(_synthetic_outcome(MoveData.HitLevel.MID, FighterStateMachine.GuardPosture.STANDING, true).result_type, HitResult.ResultType.BLOCK, "Standing Guard blocks MID")
    t.equal(_synthetic_outcome(MoveData.HitLevel.HIGH, FighterStateMachine.GuardPosture.STANDING, true).result_type, HitResult.ResultType.BLOCK, "Standing Guard blocks HIGH")
    t.equal(_synthetic_outcome(MoveData.HitLevel.LOW, FighterStateMachine.GuardPosture.STANDING, true).result_type, HitResult.ResultType.HIT, "Standing Guard loses to LOW")
    t.equal(_synthetic_outcome(MoveData.HitLevel.LOW, FighterStateMachine.GuardPosture.CROUCHING, true).result_type, HitResult.ResultType.BLOCK, "Crouching Guard blocks LOW")
    t.equal(_synthetic_outcome(MoveData.HitLevel.MID, FighterStateMachine.GuardPosture.CROUCHING, true).result_type, HitResult.ResultType.BLOCK, "Crouching Guard blocks MID")
    t.equal(_synthetic_outcome(MoveData.HitLevel.HIGH, FighterStateMachine.GuardPosture.CROUCHING, true).result_type, HitResult.ResultType.HIT, "Crouching Guard loses to HIGH")
    t.equal(_synthetic_outcome(MoveData.HitLevel.MID, FighterStateMachine.GuardPosture.STANDING, false).result_type, HitResult.ResultType.HIT, "Supported Guard HitLevel still loses to attack from behind")

func _test_real_light_and_heavy_block() -> void:
    var light_battle := _battle()
    light_battle.simulate_frame(_light(1), _guard(1, false, true))
    for _i in range(5):
        var frame := light_battle.frame_number + 1
        light_battle.simulate_frame(_neutral(frame), _guard(frame))
    var light_events := light_battle.peek_events()
    t.equal(light_battle.fighter_b.combatant.hp, 1000, "Standing Guard block of Stand Light does not reduce HP")
    t.equal(light_battle.fighter_b.combatant.hitstun_remaining, 0, "Blocked Stand Light applies no hitstun")
    t.equal(light_battle.fighter_b.combatant.blockstun_remaining, 10, "Blocked Stand Light applies 10F blockstun")
    t.equal(light_battle.fighter_b.combatant.knockback_velocity_x_units, 0, "BLOCK applies no normal hit knockback")
    t.equal(light_battle.fighter_b.state_machine.state, FighterStateMachine.State.BLOCKSTUN, "Blocked Stand Light enters BLOCKSTUN")
    t.equal(_count_events(light_events, CombatEvent.EventType.BLOCK), 1, "Stand Light emits one BLOCK event")
    t.equal(_count_events(light_events, CombatEvent.EventType.HIT), 0, "Blocked Stand Light emits no HIT event")
    var light_block_event: CombatEvent = null
    for event in light_events:
        if event.type == CombatEvent.EventType.BLOCK:
            light_block_event = event
            break
    t.that(light_block_event != null and light_block_event.hitstop_frames == 4, "Stand Light BLOCK event carries 4F hitstop contract")

    var heavy_battle := _battle()
    heavy_battle.simulate_frame(_heavy(1), _guard(1, false, true))
    for _i in range(11):
        var frame := heavy_battle.frame_number + 1
        heavy_battle.simulate_frame(_neutral(frame), _guard(frame))
    t.equal(heavy_battle.fighter_b.combatant.hp, 1000, "Standing Guard block of Stand Heavy does not reduce HP")
    t.equal(heavy_battle.fighter_b.combatant.blockstun_remaining, 13, "Blocked Stand Heavy applies 13F blockstun")
    var heavy_events := heavy_battle.peek_events()
    var heavy_block_event: CombatEvent = null
    for event in heavy_events:
        if event.type == CombatEvent.EventType.BLOCK:
            heavy_block_event = event
            break
    t.that(heavy_block_event != null and heavy_block_event.hitstop_frames == 6, "Stand Heavy BLOCK event carries 6F hitstop contract")

func _test_standing_guard_loses_to_real_low() -> void:
    var battle := _battle()
    battle.simulate_frame(_light(1, true), _guard(1, false, true))
    for _i in range(8):
        var frame := battle.frame_number + 1
        battle.simulate_frame(_neutral(frame), _guard(frame))
    t.equal(battle.fighter_b.combatant.hp, 940, "Standing Guard loses to real Crouch Low for 60 damage")
    t.equal(battle.fighter_b.combatant.hitstun_remaining, 15, "Standing Guard hit by Low receives 15F hitstun")
    t.equal(battle.fighter_b.combatant.blockstun_remaining, 0, "Standing Guard hit by Low does not receive blockstun")
    t.equal(_count_events(battle.peek_events(), CombatEvent.EventType.HIT), 1, "Standing Guard losing to Low emits HIT")

func _test_crouching_guard_blocks_real_low() -> void:
    var battle := _battle()
    battle.simulate_frame(_light(1, true), _guard(1, true, true))
    for _i in range(8):
        var frame := battle.frame_number + 1
        battle.simulate_frame(_neutral(frame), _guard(frame, true))
    t.equal(battle.fighter_b.combatant.hp, 1000, "Crouching Guard blocks real Crouch Low with zero chip")
    t.equal(battle.fighter_b.combatant.hitstun_remaining, 0, "Crouching Guard block of Low applies no hitstun")
    t.equal(battle.fighter_b.combatant.blockstun_remaining, 11, "Crouching Guard block of Low applies 11F blockstun")
    t.equal(_count_events(battle.peek_events(), CombatEvent.EventType.BLOCK), 1, "Crouching Guard Low block emits BLOCK")

func _test_block_duplicate_contact_protection() -> void:
    var battle := _battle()
    battle.simulate_frame(_heavy(1), _guard(1, false, true))
    for _i in range(25):
        var frame := battle.frame_number + 1
        battle.simulate_frame(_neutral(frame), _guard(frame))
    var events := battle.peek_events()
    t.equal(_count_events(events, CombatEvent.EventType.BLOCK), 1, "Heavy multi-frame overlap resolves BLOCK once per AttackInstanceID")
    t.equal(battle.fighter_b.combatant.hp, 1000, "Repeated active overlap does not apply repeated block chip")

func _test_blockstun_state_and_ground_settle() -> void:
    var guard_battle := _battle(40000, 100000)
    guard_battle.fighter_a.combatant.blockstun_remaining = 1
    guard_battle.fighter_a.state_machine.state = FighterStateMachine.State.BLOCKSTUN
    guard_battle.fighter_a.state_machine.guard_posture = FighterStateMachine.GuardPosture.STANDING
    guard_battle.simulate_frame(_guard(1), _neutral(1))
    t.equal(guard_battle.fighter_a.combatant.blockstun_remaining, 0, "Blockstun decrements independently to zero")
    t.equal(guard_battle.fighter_a.state_machine.state, FighterStateMachine.State.GUARD, "Blockstun expiry with Guard held settles to GUARD")

    var crouch_battle := _battle(40000, 100000)
    crouch_battle.fighter_a.combatant.blockstun_remaining = 1
    crouch_battle.fighter_a.state_machine.state = FighterStateMachine.State.BLOCKSTUN
    crouch_battle.simulate_frame(_neutral(1, 0, -1), _neutral(1))
    t.equal(crouch_battle.fighter_a.state_machine.state, FighterStateMachine.State.CROUCH, "Blockstun expiry with Down and no Guard settles to CROUCH")

    var idle_battle := _battle(40000, 100000)
    idle_battle.fighter_a.combatant.blockstun_remaining = 1
    idle_battle.fighter_a.state_machine.state = FighterStateMachine.State.BLOCKSTUN
    idle_battle.simulate_frame(_neutral(1), _neutral(1))
    t.equal(idle_battle.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Blockstun expiry with neutral settles to IDLE")

    var locked := _battle(40000, 100000)
    locked.fighter_a.combatant.blockstun_remaining = 3
    locked.fighter_a.state_machine.state = FighterStateMachine.State.BLOCKSTUN
    var start_x := locked.fighter_a.movement_motor.sim_position.x
    var light_bit := InputFrame.InputButton.LIGHT
    locked.simulate_frame(InputFrame.new(1, 1, 0, light_bit, light_bit, 0), _neutral(1))
    t.equal(locked.fighter_a.movement_motor.sim_position.x, start_x, "Blockstun fighter cannot move")
    t.that(not locked.fighter_a.move_runner.is_running(), "Blockstun fighter cannot start normal move immediately")

func _test_buffer_during_blockstun() -> void:
    var battle := _battle(40000, 100000)
    battle.fighter_a.combatant.blockstun_remaining = 3
    battle.fighter_a.state_machine.state = FighterStateMachine.State.BLOCKSTUN
    battle.simulate_frame(_light(1), _neutral(1))
    t.that(battle.fighter_a.input_buffer.has_pending(1), "Normal Light can buffer during Blockstun")
    _tick_neutral(battle, 2)
    t.equal(battle.fighter_a.combatant.blockstun_remaining, 0, "Blockstun finishes while buffered Light remains valid")
    _tick_neutral(battle, 1)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Valid buffered Light starts after Blockstun when Guard is released")

    var expired := _battle(40000, 100000)
    expired.fighter_a.combatant.blockstun_remaining = 8
    expired.fighter_a.state_machine.state = FighterStateMachine.State.BLOCKSTUN
    expired.simulate_frame(_light(1), _neutral(1))
    _tick_neutral(expired, 8)
    t.that(not expired.fighter_a.move_runner.is_running(), "Attack buffered too early during Blockstun expires without executing")

    var guarded := _battle(40000, 100000)
    guarded.fighter_a.combatant.blockstun_remaining = 3
    guarded.fighter_a.state_machine.state = FighterStateMachine.State.BLOCKSTUN
    guarded.fighter_a.state_machine.guard_posture = FighterStateMachine.GuardPosture.STANDING
    guarded.simulate_frame(_guard_and_light(1), _neutral(1))
    for _i in range(3):
        var frame := guarded.frame_number + 1
        guarded.simulate_frame(_guard(frame), _neutral(frame))
    t.equal(guarded.fighter_a.state_machine.state, FighterStateMachine.State.GUARD, "Guard priority remains after Blockstun")
    t.that(not guarded.fighter_a.move_runner.is_running(), "Buffered normal cannot bypass held Guard after Blockstun")

func _test_block_hitstop_freezes_move_timeline() -> void:
    var battle := _battle()
    battle.simulate_frame(_light(1), _guard(1, false, true))
    for _i in range(5):
        var frame := battle.frame_number + 1
        battle.simulate_frame(_neutral(frame), _guard(frame))
    t.equal(battle.fighter_a.move_runner.move_frame, 6, "Block contact freezes attacker on Light active frame 6")
    for _i in range(3):
        var frame := battle.frame_number + 1
        battle.simulate_frame(_neutral(frame), _guard(frame))
    t.equal(battle.fighter_a.move_runner.move_frame, 6, "4F block hitstop freezes MoveRunner timeline")
    var resume_frame := battle.frame_number + 1
    battle.simulate_frame(_neutral(resume_frame), _guard(resume_frame))
    t.equal(battle.fighter_a.move_runner.move_frame, 7, "MoveRunner resumes after block hitstop")

func _test_block_event_contract() -> void:
    var result := HitResult.new()
    result.attacker_id = 1
    result.defender_id = 2
    result.move_id = MoveIds.STAND_LIGHT
    result.hit_position = Vector2(10, 20)
    result.hitstop_defender = 4
    var event := CombatEvent.block(99, result, 1000, 1000)
    t.equal(event.type, CombatEvent.EventType.BLOCK, "CombatEvent.block creates BLOCK event type")
    t.equal(event.frame_number, 99, "BLOCK event captures simulation frame")
    t.equal(event.value_before, 1000, "BLOCK event captures HP before")
    t.equal(event.value_after, 1000, "Zero-chip BLOCK event preserves HP after")
    t.equal(event.hitstop_frames, 4, "BLOCK event carries defender hitstop")
