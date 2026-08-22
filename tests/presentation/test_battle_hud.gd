# M7 read-only HUD projection and round presentation mapping tests.
class_name BattleHudPresentationTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData
var generic_p: CharacterPresentationData
var rush_p: CharacterPresentationData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    generic_p = load("res://presentation/characters/generic_fighter_presentation.tres") as CharacterPresentationData
    rush_p = load("res://presentation/characters/rush_grappler_presentation.tres") as CharacterPresentationData
    _test_hud_view_model()
    _test_training_timer()
    _test_round_overlay_mapping()
    print("\nM7 BattleHUD/Round presentation tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_hud_view_model() -> void:
    var battle := BattleSimulation.new()
    battle.configure(generic, rush)
    battle.fighter_a.combatant.hp = 700
    battle.fighter_b.combatant.hp = 350
    battle.fighter_a.meter.set_value(100)
    battle.fighter_b.meter.set_value(44)
    battle.round_controller.round_timer_remaining_frames = 3599
    battle.round_controller.p1_round_wins = 1
    var vm := BattleHudViewModel.new()
    vm.update_from(battle, generic_p, rush_p)
    t.equal(vm.p1_name, "Salad Cat", "HUD uses production CharacterPresentationData display name")
    t.equal(vm.p2_name, "Rush Grappler", "HUD P2 display name comes from presentation data")
    t.equal(vm.p1_hp, 700, "HUD reads P1 authoritative HP")
    t.equal(vm.p2_hp, 350, "HUD reads P2 authoritative HP")
    t.equal(vm.p1_meter, 100, "HUD reads P1 authoritative meter")
    t.equal(vm.p2_meter, 44, "HUD reads P2 authoritative meter")
    t.equal(vm.timer_text, "60", "3599F timer displays ceil(frames/60) without changing gameplay frames")
    t.equal(vm.p1_wins, 1, "HUD reads RoundController round wins")

func _test_training_timer() -> void:
    var battle := BattleSimulation.new()
    battle.configure(generic, rush, null, null, Vector2i(50000, 56000), Vector2i(78000, 56000), MatchRulesData.training_defaults())
    var vm := BattleHudViewModel.new()
    vm.update_from(battle, generic_p, rush_p)
    t.that(vm.training, "Training HUD mode derives from MatchRulesData")
    t.equal(vm.timer_text, "∞", "Training timer displays infinity as presentation text only")
    t.equal(battle.round_controller.round_timer_remaining_frames, 0, "Training gameplay timer remains deterministic integer zero")

func _test_round_overlay_mapping() -> void:
    var overlay := RoundPresentationOverlay.new()
    overlay.present_event(CombatEvent.round_started(1, 1))
    t.that("ROUND 1" in overlay.visual_message and "FIGHT" in overlay.visual_message, "Round start maps to ROUND/FIGHT overlay")
    var ko := CombatEvent.new()
    ko.type = CombatEvent.EventType.KO
    overlay.present_event(ko)
    t.equal(overlay.visual_message, "KO", "KO event maps to KO overlay")
    overlay.present_event(CombatEvent.time_up(100, 1, RoundController.RoundResult.P1_WIN))
    t.equal(overlay.visual_message, "TIME UP", "TIME_UP event maps to TIME UP overlay")
    overlay.present_event(CombatEvent.round_ended(101, 1, RoundController.RoundResult.DRAW, false))
    t.equal(overlay.visual_message, "DRAW", "Draw round result maps to DRAW overlay")
    overlay.present_event(CombatEvent.match_ended(200, RoundController.Participant.P2, 3))
    t.that("P2 WINS" in overlay.visual_message and "MATCH OVER" in overlay.visual_message, "Match winner maps to player-facing winner overlay")
    overlay.free()
