# Responsibility: M6 Training MatchRules, disabled timer, KO auto-reset, score and permanent-match-over suppression.
class_name Milestone6TrainingTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var generic: CharacterData
var training: MatchRulesData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    training = load("res://data/match_rules/training_match_rules.tres") as MatchRulesData
    _test_training_rules_and_timer()
    _test_training_ko_auto_reset_and_projectile_cleanup()
    print("\nM6 Training tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle() -> BattleSimulation:
    var b := BattleSimulation.new()
    b.configure(zone, generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(78000, BattleSimulation.GROUND_Y_UNITS), training)
    return b

func _tick(b: BattleSimulation) -> void:
    var f := b.frame_number + 1
    b.simulate_frame(InputFrame.neutral(f), InputFrame.neutral(f))

func _test_training_rules_and_timer() -> void:
    t.that(training.is_valid(), "Training MatchRulesData validates")
    t.equal(training.id, &"training", "Training rules stable ID is training")
    t.equal(training.timer_enabled, false, "Training timer disabled")
    t.equal(training.post_round_frames, 60, "Training post-round is 60F")
    t.equal(training.match_can_end, false, "Training cannot permanently end match")
    var battle := _battle()
    for _i in range(300):
        _tick(battle)
    t.equal(battle.round_controller.round_timer_remaining_frames, 0, "Training timer stays deterministic zero and never decrements")
    t.equal(battle.round_controller.state, RoundController.State.ROUND_ACTIVE, "Training does not timeout during long active run")

func _test_training_ko_auto_reset_and_projectile_cleanup() -> void:
    var battle := _battle()
    var configured_start_a := battle.configured_start_position(1)
    var configured_start_b := battle.configured_start_position(2)
    var special := battle.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, special.projectile_spawns[0])
    battle.fighter_b.combatant.hp = 0
    battle.fighter_b.combatant.is_ko = true
    _tick(battle)
    t.equal(battle.round_controller.state, RoundController.State.POST_ROUND, "Training KO still enters POST_ROUND")
    t.equal(battle.round_controller.post_round_remaining_frames, 60, "Training KO gets full 60F post-round")
    t.equal(battle.projectile_system.active_count(), 0, "Training KO uses generic temporary-entity cleanup")
    t.equal(battle.round_controller.p1_round_wins, 0, "Training KO never increments P1 score")
    for _i in range(60):
        _tick(battle)
    t.equal(battle.round_controller.state, RoundController.State.ROUND_ACTIVE, "Training auto-resets after 60F")
    t.equal(battle.round_controller.round_number, 1, "Training reset keeps round_number fixed at 1")
    t.equal(battle.round_controller.p1_round_wins, 0, "Training score remains zero after reset")
    t.equal(battle.round_controller.p2_round_wins, 0, "Training P2 score remains zero after reset")
    t.equal(battle.fighter_b.combatant.hp, 5000, "Training auto-reset restores KO fighter HP")
    t.equal(battle.fighter_a.movement_motor.sim_position, configured_start_a, "Training round reset restores simulation-configured P1 start")
    t.equal(battle.fighter_b.movement_motor.sim_position, configured_start_b, "Training round reset restores simulation-configured P2 start")
    t.that(not battle.round_controller.is_match_over(), "Training never enters MATCH_OVER")
