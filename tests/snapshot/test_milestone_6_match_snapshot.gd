# Responsibility: M6 snapshot v6 MatchRules/RoundController capture/restore/hash and round-boundary re-simulation safety.
class_name Milestone6MatchSnapshotTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var zone: CharacterData
var versus: MatchRulesData
var training: MatchRulesData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    versus = load("res://data/match_rules/versus_match_rules.tres") as MatchRulesData
    training = load("res://data/match_rules/training_match_rules.tres") as MatchRulesData
    _test_active_round_snapshot_fields_and_restore()
    _test_post_round_snapshot_and_transition_hash()
    _test_match_over_snapshot_input_lock_restore()
    _test_rules_mismatch_rejected()
    _test_rules_identity_changes_hash()
    _test_projectile_round_cleanup_restore_replay()
    print("\nM6 Match Snapshot tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(rules: MatchRulesData = null, a: CharacterData = null, b: CharacterData = null) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        a if a != null else generic,
        b if b != null else generic,
        null,
        null,
        Vector2i(50000, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(78000, BattleSimulation.GROUND_Y_UNITS),
        rules if rules != null else versus
    )
    return battle

func _tick(battle: BattleSimulation) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(InputFrame.neutral(frame), InputFrame.neutral(frame))

func _test_active_round_snapshot_fields_and_restore() -> void:
    var battle := _battle()
    battle.round_controller.round_number = 2
    battle.round_controller.p1_round_wins = 1
    battle.round_controller.round_timer_remaining_frames = 2417
    var snapshot := battle.capture_state()
    t.equal(snapshot.version, BattleStateSnapshot.VERSION, "Current snapshot schema follows BattleStateSnapshot.VERSION")
    t.equal(snapshot.round_state.rules_id, &"versus", "Snapshot captures stable MatchRules ID")
    t.equal(snapshot.round_state.state, RoundController.State.ROUND_ACTIVE, "Snapshot captures ROUND_ACTIVE")
    t.equal(snapshot.round_state.round_number, 2, "Snapshot captures round number")
    t.equal(snapshot.round_state.p1_round_wins, 1, "Snapshot captures P1 round wins")
    t.equal(snapshot.round_state.round_timer_remaining_frames, 2417, "Snapshot captures exact integer timer")
    battle.round_controller.round_number = 9
    battle.round_controller.round_timer_remaining_frames = 1
    t.that(battle.restore_state(snapshot), "Same-rules active round snapshot restores")
    t.equal(battle.round_controller.round_number, 2, "Restore recovers exact round number")
    t.equal(battle.round_controller.round_timer_remaining_frames, 2417, "Restore recovers exact timer")

func _test_post_round_snapshot_and_transition_hash() -> void:
    var battle := _battle()
    battle.fighter_b.combatant.hp = 0
    battle.fighter_b.combatant.is_ko = true
    _tick(battle)
    for _i in range(47):
        _tick(battle)
    t.equal(battle.round_controller.post_round_remaining_frames, 43, "Setup reaches POST_ROUND remaining=43")
    var snapshot := battle.capture_state()
    t.equal(snapshot.round_state.round_result, RoundController.RoundResult.P1_WIN, "POST_ROUND snapshot captures round result")
    for _i in range(43):
        _tick(battle)
    var hash_a := battle.state_signature()
    t.that(battle.restore_state(snapshot), "POST_ROUND snapshot restores")
    for _i in range(43):
        _tick(battle)
    t.equal(battle.state_signature(), hash_a, "POST_ROUND restore/replay starts next round on identical frame/hash")

func _test_match_over_snapshot_input_lock_restore() -> void:
    var battle := _battle()
    battle.round_controller.state = RoundController.State.MATCH_OVER
    battle.round_controller.p1_round_wins = 2
    battle.round_controller.p2_round_wins = 1
    battle.round_controller.round_result = RoundController.RoundResult.P1_WIN
    battle.round_controller.pending_match_winner = RoundController.Participant.P1
    battle.round_controller.match_winner = RoundController.Participant.P1
    var snapshot := battle.capture_state()
    battle.round_controller.state = RoundController.State.ROUND_ACTIVE
    t.that(battle.restore_state(snapshot), "MATCH_OVER snapshot restores")
    t.equal(battle.round_controller.match_winner, RoundController.Participant.P1, "MATCH_OVER restore preserves participant winner")
    var before := battle.fighter_a.movement_motor.sim_position
    battle.simulate_frame(InputFrame.with_light_press(battle.frame_number + 1), InputFrame.neutral(battle.frame_number + 1))
    t.equal(battle.fighter_a.movement_motor.sim_position, before, "Restored MATCH_OVER remains gameplay locked")

func _test_rules_mismatch_rejected() -> void:
    var versus_battle := _battle(versus)
    var snapshot := versus_battle.capture_state()
    var training_battle := _battle(training)
    t.that(not training_battle.restore_state(snapshot), "Versus snapshot restore into Training rules is rejected")

func _test_rules_identity_changes_hash() -> void:
    var snapshot := _battle(versus).capture_state()
    var clone := _battle(versus).capture_state()
    clone.round_state.rules_id = &"training"
    # Keep every other mutable field identical so only immutable rules identity changes canonical state input.
    clone.round_state.round_timer_remaining_frames = snapshot.round_state.round_timer_remaining_frames
    t.that(BattleStateHasher.hash_snapshot(snapshot) != BattleStateHasher.hash_snapshot(clone), "Same gameplay fields with different MatchRules ID produce different state hashes")

func _test_projectile_round_cleanup_restore_replay() -> void:
    var battle := _battle(versus, zone, generic)
    var special := battle.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, special.projectile_spawns[0])
    battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, special.projectile_spawns[0])
    var snapshot := battle.capture_state()
    battle.fighter_b.combatant.hp = 0
    battle.fighter_b.combatant.is_ko = true
    _tick(battle)
    var hash_after_cleanup := battle.state_signature()
    t.equal(battle.projectile_system.active_count(), 0, "Round-ending tick clears captured detached projectiles after outcomes")
    t.that(battle.restore_state(snapshot), "Active-round snapshot with two projectiles restores")
    battle.fighter_b.combatant.hp = 0
    battle.fighter_b.combatant.is_ko = true
    _tick(battle)
    t.equal(battle.state_signature(), hash_after_cleanup, "Projectile + round cleanup boundary re-simulates to identical hash")
