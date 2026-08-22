# Responsibility: Render-free deterministic 10,000 gameplay-frame stress plus M6 replay determinism stress.
# Coverage: three-character core, projectiles, round/match cycles, full-match resets, snapshot integrity, replay reconstruction.
class_name SimulationStressTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData
var zone: CharacterData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    _test_10000_deterministic_frames()
    _test_replay_determinism_stress()
    print("\nSimulation Stress tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _stress_rules(timer_frames: int) -> MatchRulesData:
    var rules := MatchRulesData.versus_defaults()
    rules.rounds_to_win = 1
    rules.round_timer_frames = timer_frames
    rules.post_round_frames = 6
    return rules

func _test_10000_deterministic_frames() -> void:
    var violations: PackedStringArray = []
    var total_frames := 0
    total_frames += _run_segment(generic, generic, 2000, "generic_vs_generic", violations, 180)
    total_frames += _run_segment(rush, rush, 2000, "rush_vs_rush", violations, 180)
    total_frames += _run_segment(generic, rush, 2000, "generic_vs_rush", violations, 180)
    total_frames += _run_segment(zone, generic, 4000, "zone_vs_generic_projectiles", violations, 300)
    t.equal(total_frames, 10000, "Stress test executes exactly 10,000 render-free simulation ticks with round/match/projectile coverage")
    t.equal(violations.size(), 0, "Stress invariants hold: %s" % "; ".join(violations))

func _run_segment(
    character_a: CharacterData,
    character_b: CharacterData,
    frame_count: int,
    label: String,
    violations: PackedStringArray,
    timer_frames: int
) -> int:
    var battle := BattleSimulation.new()
    var start_a := Vector2i(50000, BattleSimulation.GROUND_Y_UNITS) if character_a.id == &"zone_fighter" else Vector2i(36000, BattleSimulation.GROUND_Y_UNITS)
    var start_b := Vector2i(61000, BattleSimulation.GROUND_Y_UNITS) if character_a.id == &"zone_fighter" else Vector2i(90000, BattleSimulation.GROUND_Y_UNITS)
    battle.configure(character_a, character_b, null, null, start_a, start_b, _stress_rules(timer_frames))
    # Symmetric scripted inputs can reach timeout with exactly equal HP. Give P1
    # a deterministic one-point lead so every segment exercises MATCH_OVER and
    # the explicit full-match reset path without changing production tuning.
    battle.fighter_b.combatant.hp -= 1
    var airborne_age := [0, 0]
    var state_age := [0, 0]
    var last_state := [battle.fighter_a.state_machine.state, battle.fighter_b.state_machine.state]
    var expected_ids := [character_a.id, character_b.id]
    var full_match_resets := 0
    var observed_post_round := false

    for step in range(1, frame_count + 1):
        var pre_meter := [battle.fighter_a.meter.get_value(), battle.fighter_b.meter.get_value()]
        var pre_instance := [battle.fighter_a.move_runner.attack_instance_id, battle.fighter_b.move_runner.attack_instance_id]
        battle.simulate_frame(_scripted_input(battle.frame_number + 1, 1), _scripted_input(battle.frame_number + 1, -1))
        if battle.round_controller.is_post_round():
            observed_post_round = true
        var fighters := [battle.fighter_a, battle.fighter_b]
        for i in range(2):
            var fighter: Fighter = fighters[i]
            var state := fighter.state_machine.state
            if state == last_state[i]:
                state_age[i] += 1
            else:
                state_age[i] = 0
                last_state[i] = state
            if fighter.movement_motor.is_airborne():
                airborne_age[i] += 1
            else:
                airborne_age[i] = 0
            var issue := _invariant_issue(fighter, battle.frame_number, airborne_age[i], state_age[i], expected_ids[i])
            if issue != "" and violations.size() < 20:
                violations.append("%s F%d P%d %s" % [label, battle.frame_number, fighter.fighter_id, issue])
            if fighter.move_runner.current_move_id() == MoveIds.ULTIMATE and fighter.move_runner.attack_instance_id != pre_instance[i] and pre_meter[i] < 100 and violations.size() < 20:
                violations.append("%s F%d P%d Ultimate started below 100 meter" % [label, battle.frame_number, fighter.fighter_id])

        var projectile_issue := _projectile_invariant_issue(battle)
        if projectile_issue != "" and violations.size() < 20:
            violations.append("%s F%d %s" % [label, battle.frame_number, projectile_issue])
        var match_issue := _match_invariant_issue(battle)
        if match_issue != "" and violations.size() < 20:
            violations.append("%s F%d %s" % [label, battle.frame_number, match_issue])

        # Periodic same-build snapshot/restore must be state-neutral across ACTIVE/POST/MATCH lifecycle states.
        if step % 401 == 0:
            var before_hash := battle.state_signature()
            var snapshot: BattleStateSnapshot = battle.capture_state()
            if not battle.restore_state(snapshot) and violations.size() < 20:
                violations.append("%s F%d snapshot restore rejected its own current state" % [label, battle.frame_number])
            elif battle.state_signature() != before_hash and violations.size() < 20:
                violations.append("%s F%d snapshot identity hash changed after immediate restore" % [label, battle.frame_number])

        if not battle.fighter_a.movement_motor.is_airborne() and not battle.fighter_b.movement_motor.is_airborne():
            var a_rect := battle.fighter_a.hitbox_owner.pushbox_rect(battle.fighter_a.position_pixels(), battle.fighter_a.movement_motor.facing)
            var b_rect := battle.fighter_b.hitbox_owner.pushbox_rect(battle.fighter_b.position_pixels(), battle.fighter_b.movement_motor.facing)
            if a_rect.intersects(b_rect) and violations.size() < 20:
                violations.append("%s F%d grounded pushboxes remain overlapped" % [label, battle.frame_number])

        # Keep long stress productive after a first-to-two completes; only an explicit full match reset returns global frame to zero.
        if battle.round_controller.is_match_over():
            battle.reset_full_match()
            full_match_resets += 1
            last_state = [battle.fighter_a.state_machine.state, battle.fighter_b.state_machine.state]
            state_age = [0, 0]
            airborne_age = [0, 0]

    if not observed_post_round and violations.size() < 20:
        violations.append("%s did not exercise any round transition" % label)
    if full_match_resets <= 0 and violations.size() < 20:
        violations.append("%s did not exercise MATCH_OVER -> explicit full match reset" % label)
    return frame_count

func _test_replay_determinism_stress() -> void:
    # Separate from the required 10,000F gameplay stress: 1,800 authoritative replay frames across repeated round resets.
    var rules_a := MatchRulesData.versus_defaults()
    rules_a.rounds_to_win = 99
    rules_a.round_timer_frames = 90
    rules_a.post_round_frames = 2
    var battle_a := BattleSimulation.new()
    battle_a.configure(zone, rush, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(60000, BattleSimulation.GROUND_Y_UNITS), rules_a)
    var recorder := ReplayRecorder.new()
    t.that(recorder.begin_recording(rules_a.id, zone.id, rush.id, 0), "Replay stress recorder accepts same-build versus metadata")
    battle_a.set_replay_recorder(recorder)
    for _step in range(1800):
        var frame := battle_a.frame_number + 1
        battle_a.simulate_frame(_scripted_input(frame, 1), _scripted_input(frame, -1))
    var expected_hash := battle_a.state_signature()
    t.that(recorder.finish_recording(expected_hash), "Replay stress records 1,800 continuous normalized frame pairs and final hash")
    var replay := recorder.replay_data()
    t.equal(replay.frame_count(), 1800, "Replay stress source contains exactly 1,800 continuous frame pairs")

    var source_a := ReplayInputSource.new()
    var source_b := ReplayInputSource.new()
    t.that(source_a.configure(replay, 1) and source_b.configure(replay, 2), "Replay stress configures random-access normalized InputSources")
    var rules_b := MatchRulesData.versus_defaults()
    rules_b.rounds_to_win = 99
    rules_b.round_timer_frames = 90
    rules_b.post_round_frames = 2
    var battle_b := BattleSimulation.new()
    battle_b.configure(zone, rush, source_a, source_b, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(60000, BattleSimulation.GROUND_Y_UNITS), rules_b)
    for _step in range(replay.frame_count()):
        battle_b.sample_and_simulate_frame()
    t.equal(battle_b.state_signature(), replay.expected_final_state_hash, "Replay deterministic stress fresh Battle reproduces exact final BattleStateHasher value")

func _scripted_input(frame: int, toward_sign: int) -> InputFrame:
    var phase := frame % 180
    var direction_x := 0
    var direction_y := 0
    var held := 0
    var pressed := 0
    if phase == 1:
        direction_y = 1
    elif phase == 2:
        held = InputFrame.InputButton.LIGHT
        pressed = held
    elif phase == 55:
        direction_x = toward_sign
    elif phase == 56:
        direction_x = 0
    elif phase == 57:
        direction_x = toward_sign
    elif phase == 85:
        direction_x = -toward_sign
    elif phase == 86:
        direction_x = 0
    elif phase == 87:
        direction_x = -toward_sign
    elif phase == 105:
        held = InputFrame.InputButton.SPECIAL
        pressed = held
    elif phase == 120:
        direction_x = toward_sign
        held = InputFrame.InputButton.HEAVY
        pressed = held
    elif phase == 135:
        held = InputFrame.InputButton.ULTIMATE
        pressed = held
    elif phase in [145, 146, 147, 148, 149]:
        held = InputFrame.InputButton.GUARD
    return InputFrame.new(frame, direction_x, direction_y, held, pressed, 0)

func _invariant_issue(fighter: Fighter, current_frame: int, airborne_age: int, state_age: int, expected_character_id: StringName) -> String:
    var state := fighter.state_machine.state
    var root := fighter.state_machine.root_state
    if fighter.data == null or fighter.data.id == &"":
        return "character_id never empty invariant failed"
    if fighter.data.id != expected_character_id:
        return "snapshot identity stays stable / fighter CharacterData identity changed"
    if fighter.move_registry == null or fighter.data.move_set == null:
        return "Fighter registry matches its CharacterData invariant failed"
    for configured_move: MoveData in fighter.data.move_set.moves:
        if configured_move == null or fighter.move_registry.get_move(configured_move.id) != configured_move:
            return "no registry cross-contamination invariant failed"
    if not FighterStateMachine.State.values().has(state):
        return "invalid state enum"
    if not FighterStateMachine.RootState.values().has(root):
        return "invalid root enum"
    if fighter.state_machine._root_for_state(state) != root:
        return "impossible root/leaf pair"
    if abs(fighter.movement_motor.sim_position.x) > 1000000 or abs(fighter.movement_motor.sim_position.y) > 1000000:
        return "position escaped sane integer range"
    if root == FighterStateMachine.RootState.GROUNDED and fighter.movement_motor.sim_position.y != BattleSimulation.GROUND_Y_UNITS:
        return "grounded Y is not exact ground_y"
    if airborne_age > 180:
        return "airborne did not eventually land"
    if fighter.combatant.hp < 0 or fighter.combatant.hp > fighter.combatant.max_hp:
        return "HP outside valid range"
    if fighter.meter.get_value() < MeterComponent.MIN_VALUE or fighter.meter.get_value() > MeterComponent.MAX_VALUE:
        return "meter outside 0..100"
    if fighter.combatant.is_ko and state != FighterStateMachine.State.KO:
        return "KO can act / not in KO state"
    if fighter.move_runner.is_running():
        if fighter.move_runner.current_move == null:
            return "null MoveData runtime reference"
        if not fighter.move_registry.has_move(fighter.move_runner.current_move_id()):
            return "invalid current move ID"
        if fighter.move_registry.get_move(fighter.move_runner.current_move_id()) != fighter.move_runner.current_move:
            return "current_move_id always exists in that fighter registry / wrong MoveData identity"
        if fighter.move_runner.attack_instance_id <= 0 or fighter.move_runner.instance_serial() <= 0:
            return "invalid AttackInstance serial"
        if fighter.move_runner.move_frame <= 0 or fighter.move_runner.move_frame > fighter.move_runner.current_move.total_frames():
            return "stuck MoveRunner / move lasting forever"
    if fighter.input_buffer.has_pending(current_frame) and fighter.input_buffer.expiry_frame() < current_frame:
        return "input buffer failed to expire"
    if state in [FighterStateMachine.State.HITSTUN, FighterStateMachine.State.BLOCKSTUN] and state_age > 300:
        return "stun did not eventually exit"
    if state in [FighterStateMachine.State.THROWN, FighterStateMachine.State.KNOCKDOWN, FighterStateMachine.State.GETUP] and state_age > 400:
        return "forced reaction did not eventually exit"
    if state in [FighterStateMachine.State.DASH_FORWARD, FighterStateMachine.State.BACKSTEP] and state_age > 60:
        return "Dash/Backstep did not eventually exit"
    return ""

func _projectile_invariant_issue(battle: BattleSimulation) -> String:
    var last_id := 0
    var seen: Array[int] = []
    for projectile: ProjectileRuntime in battle.projectile_system.active_projectiles():
        if projectile.instance_id <= last_id or seen.has(projectile.instance_id):
            return "projectile IDs/order are not deterministic unique ascending values"
        seen.append(projectile.instance_id)
        last_id = projectile.instance_id
        if projectile.owner_fighter_id != 1 and projectile.owner_fighter_id != 2:
            return "projectile owner participant invalid"
        if projectile.projectile_id == &"" or projectile.source_move_id == &"":
            return "projectile stable data identity empty"
        if projectile.remaining_lifetime_frames <= 0:
            return "expired projectile survived cleanup"
        var owner := battle.fighter_by_id(projectile.owner_fighter_id)
        if owner == null:
            return "projectile owner cannot be resolved"
        var source_move := owner.move_registry.get_move(projectile.source_move_id)
        if source_move == null or projectile.spawn_index < 0 or projectile.spawn_index >= source_move.projectile_spawns.size():
            return "projectile source MoveRegistry rehydration invalid"
        var descriptor: ProjectileSpawnData = source_move.projectile_spawns[projectile.spawn_index]
        if descriptor == null or descriptor.projectile_data == null or descriptor.projectile_data.id != projectile.projectile_id:
            return "projectile registry/data cross-contamination"
    if battle.projectile_system.next_projectile_instance_serial <= last_id:
        return "next projectile serial not greater than all active IDs"
    if not battle.round_controller.is_round_active() and not battle.projectile_system.active_projectiles().is_empty():
        return "temporary projectile survived POST_ROUND/MATCH_OVER cleanup"
    return ""

func _match_invariant_issue(battle: BattleSimulation) -> String:
    var rc := battle.round_controller
    if rc == null or rc.rules == null or rc.rules.id == &"":
        return "round rules stable identity missing"
    if rc.state < RoundController.State.ROUND_ACTIVE or rc.state > RoundController.State.MATCH_OVER:
        return "invalid round lifecycle state"
    if rc.round_number < 1 or rc.p1_round_wins < 0 or rc.p2_round_wins < 0:
        return "invalid round number/win counters"
    if rc.round_timer_remaining_frames < 0 or rc.post_round_remaining_frames < 0:
        return "negative deterministic round timer"
    if rc.is_round_active() and rc.round_result != RoundController.RoundResult.NONE:
        return "ROUND_ACTIVE retains stale round result"
    if rc.is_post_round() and rc.round_result == RoundController.RoundResult.NONE:
        return "POST_ROUND missing authoritative result"
    if rc.is_match_over() and rc.match_winner == RoundController.Participant.NONE:
        return "MATCH_OVER missing participant winner"
    return ""
