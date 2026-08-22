# Responsibility: M6 deterministic frame timer, hitstop freeze, timeout ordering and KO priority tests.
class_name Milestone6TimeoutTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rules: MatchRulesData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rules = load("res://data/match_rules/versus_match_rules.tres") as MatchRulesData
    _test_timeout_p1_p2_draw()
    _test_last_frame_uses_post_apply_hp_contract()
    _test_ko_precedence_over_timeout()
    _test_hitstop_freezes_timer()
    print("\nM6 Timeout tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle() -> BattleSimulation:
    var b := BattleSimulation.new()
    b.configure(generic, generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(78000, BattleSimulation.GROUND_Y_UNITS), rules)
    return b

func _tick(b: BattleSimulation) -> void:
    var f := b.frame_number + 1
    b.simulate_frame(InputFrame.neutral(f), InputFrame.neutral(f))

func _test_timeout_p1_p2_draw() -> void:
    var p1 := _battle()
    p1.round_controller.round_timer_remaining_frames = 1
    p1.fighter_a.combatant.hp = 700
    p1.fighter_b.combatant.hp = 600
    _tick(p1)
    t.equal(p1.round_controller.round_result, RoundController.RoundResult.P1_WIN, "Timeout awards P1 when post-apply P1 HP is higher")

    var p2 := _battle()
    p2.round_controller.round_timer_remaining_frames = 1
    p2.fighter_a.combatant.hp = 500
    p2.fighter_b.combatant.hp = 800
    _tick(p2)
    t.equal(p2.round_controller.round_result, RoundController.RoundResult.P2_WIN, "Timeout awards P2 when post-apply P2 HP is higher")

    var draw := _battle()
    draw.round_controller.round_timer_remaining_frames = 1
    draw.fighter_a.combatant.hp = 650
    draw.fighter_b.combatant.hp = 650
    _tick(draw)
    t.equal(draw.round_controller.round_result, RoundController.RoundResult.DRAW, "Equal HP at timer zero produces DRAW")
    t.equal(draw.round_controller.p1_round_wins, 0, "Timeout DRAW gives no P1 round win")
    t.equal(draw.round_controller.p2_round_wins, 0, "Timeout DRAW gives no P2 round win")

func _test_last_frame_uses_post_apply_hp_contract() -> void:
    var controller := RoundController.new()
    controller.configure(rules)
    controller.round_timer_remaining_frames = 1
    # BattleSimulation calls this only after all contact results have applied; use the resulting 600/550 HP here.
    var ended := controller.evaluate_active_tick(false, false, 600, 550, false)
    t.that(ended, "Final timer tick resolves after the combat apply phase")
    t.equal(controller.round_result, RoundController.RoundResult.P1_WIN, "Last-frame damage is reflected in timeout HP comparison")
    t.equal(controller.round_timer_remaining_frames, 0, "Final active timer frame decrements 1 -> 0 exactly")

func _test_ko_precedence_over_timeout() -> void:
    var controller := RoundController.new()
    controller.configure(rules)
    controller.round_timer_remaining_frames = 1
    controller.evaluate_active_tick(false, true, 100, 900, false)
    t.equal(controller.round_result, RoundController.RoundResult.P1_WIN, "KO result overrides contradictory timeout HP comparison")
    t.equal(controller.round_timer_remaining_frames, 1, "KO path does not need timeout decrement to decide result")

func _test_hitstop_freezes_timer() -> void:
    var battle := _battle()
    battle.round_controller.round_timer_remaining_frames = 100
    battle.fighter_a.combatant.hitstop_remaining = 4
    battle.fighter_b.combatant.hitstop_remaining = 4
    for _i in range(4):
        _tick(battle)
    t.equal(battle.round_controller.round_timer_remaining_frames, 100, "Four gameplay-hitstop ticks freeze round timer at 100")
    _tick(battle)
    t.equal(battle.round_controller.round_timer_remaining_frames, 99, "First normal tick after hitstop decrements timer once")
