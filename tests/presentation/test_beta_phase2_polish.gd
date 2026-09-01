# Beta Phase 2 regression tests for presentation-only spectacle and audio hooks.
class_name BetaPhase2PolishTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const MENU_AUDIO := preload("res://presentation/audio/menu_audio_presenter.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_menu_confirm_hook()
    _test_camera_emphasis_is_visual_only()
    _test_all_roster_ultimate_presentation_resolves()
    _test_finisher_uses_generic_spectacle_pulse()
    print("\nBeta Phase 2 presentation polish tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_menu_confirm_hook() -> void:
    var menu_audio := MENU_AUDIO.new()
    menu_audio.present_confirm()
    t.equal(menu_audio.last_cue, &"menu_confirm", "Menu confirm exposes a presentation-only audio cue")
    t.equal(menu_audio.cue_dispatch_count, 1, "Menu confirmation dispatches exactly one cue")
    menu_audio.free()

func _test_camera_emphasis_is_visual_only() -> void:
    var camera := BattleCameraController.new()
    var camera_2d := Camera2D.new()
    camera_2d.name = "Camera2D"
    camera.add_child(camera_2d)
    camera.request_emphasis(0.075, 0.22)
    t.that(camera.emphasis_remaining_seconds > 0.0, "Ultimate/KO emphasis owns only render-time duration")
    t.that(camera_2d.zoom.x < 1.0, "Ultimate/KO emphasis changes Camera2D zoom only")
    camera.reset_feedback()
    t.equal(camera_2d.zoom, Vector2.ONE, "Camera reset restores neutral presentation zoom")
    camera.free()

func _test_all_roster_ultimate_presentation_resolves() -> void:
    for entry: Dictionary in RosterRegistry.ENTRIES:
        var presentation := entry["presentation"] as CharacterPresentationData
        var animation := presentation.animation_for_move(&"ultimate", &"attack")
        t.that(animation != &"" and presentation.production_asset_binding != null,
            "%s Ultimate resolves through the production presentation path" % String(entry["id"]))

func _test_finisher_uses_generic_spectacle_pulse() -> void:
    var pink := RosterRegistry.character_by_id(&"pink_star")
    var opponent := RosterRegistry.character_by_id(&"doge")
    var battle := BattleSimulation.new()
    battle.configure(pink, opponent)
    var presenter := UltimateScreenPresenter.new()
    presenter.configure(battle, [RosterRegistry.presentation_by_id(&"pink_star")])
    presenter.present_event(CombatEvent.move_started(1, battle.fighter_a.fighter_id, &"pink_true_finisher_3", 1))
    t.equal(presenter.active_count(), 1, "Finisher receives a generic screen-space spectacle pulse without a gameplay branch")
    presenter.free()
