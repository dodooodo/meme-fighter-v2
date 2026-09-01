# M7 VFX/audio/camera one-shot dispatch through shared event ledger.
class_name FeedbackPresenterTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_shared_dedupe()
    _test_feedback_hierarchy()
    _test_authored_level_and_finisher_feedback()
    _test_audio_cue_categories()
    _test_block_and_ko_are_distinct()
    _test_camera_follow_and_reset()
    print("\nM7 feedback presenter tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _event() -> CombatEvent:
    return _hit_event(&"stand_heavy")

func _hit_event(move_id: StringName) -> CombatEvent:
    var result := HitResult.new()
    result.attacker_id = 1
    result.defender_id = 2
    result.move_id = move_id
    result.attack_instance_id = 9
    result.hit_position = Vector2(600, 450)
    return CombatEvent.hit(20, result, 1000, 900)

func _test_feedback_hierarchy() -> void:
    var moves := [&"stand_light", &"stand_heavy", &"special_neutral", &"ultimate"]
    var previous_intensity := 0.0
    var previous_shake := 0.0
    var previous_flash := 0.0
    for move_id: StringName in moves:
        var event := _hit_event(move_id)
        var vfx := CombatVfxPresenter.new()
        var audio := CombatAudioPresenter.new()
        var camera := BattleCameraController.new()
        vfx.present_event(event)
        audio.present_event(event)
        camera.present_event(event)
        t.that(vfx.last_impact_intensity > previous_intensity, "%s VFX intensity exceeds prior tier" % String(move_id))
        t.that(camera.shake_strength_pixels > previous_shake, "%s camera impulse exceeds prior tier" % String(move_id))
        t.that(vfx.last_flash_alpha > previous_flash, "%s white flash exceeds prior tier" % String(move_id))
        t.equal(audio.last_cue, StringName("hit_%s" % CombatFeedbackProfile.tier_name_for_move(move_id)), "%s uses tiered hit cue" % String(move_id))
        previous_intensity = vfx.last_impact_intensity
        previous_shake = camera.shake_strength_pixels
        previous_flash = vfx.last_flash_alpha
        vfx.free()
        audio.free()
        camera.free()

func _test_block_and_ko_are_distinct() -> void:
    var block_result := HitResult.new()
    block_result.attacker_id = 1
    block_result.defender_id = 2
    block_result.move_id = &"stand_heavy"
    block_result.attack_instance_id = 11
    block_result.hit_position = Vector2(600, 450)
    var block_event := CombatEvent.block(30, block_result, 1000, 1000)
    var block_vfx := CombatVfxPresenter.new()
    var block_audio := CombatAudioPresenter.new()
    block_vfx.present_event(block_event)
    block_audio.present_event(block_event)
    t.equal(block_audio.last_cue, &"block_heavy", "Block uses a distinct tiered guard cue")
    t.that(block_vfx.last_flash_alpha < CombatFeedbackProfile.flash_alpha_for(CombatEvent.EventType.HIT, 2), "Block flash stays below same-tier hit")

    var ko_event := CombatEvent.ko(31, block_result)
    var ko_vfx := CombatVfxPresenter.new()
    var ko_camera := BattleCameraController.new()
    ko_vfx.present_event(ko_event)
    ko_camera.present_event(ko_event)
    t.that(ko_vfx.last_flash_alpha >= CombatFeedbackProfile.flash_alpha_for(CombatEvent.EventType.HIT, 4), "KO flash is at least Ultimate-hit strength")
    t.that(ko_camera.shake_strength_pixels >= CombatFeedbackProfile.camera_strength_for(CombatEvent.EventType.HIT, 4), "KO camera impulse is at least Ultimate-hit strength")
    block_vfx.free()
    block_audio.free()
    ko_vfx.free()
    ko_camera.free()

func _test_authored_level_and_finisher_feedback() -> void:
    var special_moves := [&"doge_rush_l3", &"salad_wave_l3", &"magic_circle_l2", &"bao_counter_success_l3"]
    for move_id: StringName in special_moves:
        t.equal(CombatFeedbackProfile.tier_for_move(move_id), 3,
            "%s resolves to the readable Special feedback tier" % String(move_id))
    t.equal(CombatFeedbackProfile.tier_for_move(&"pink_true_finisher_5"), 4,
        "Finisher hit feedback resolves to the Ultimate tier")

func _test_audio_cue_categories() -> void:
    t.equal(CombatFeedbackProfile.audio_cue_for_move(CombatEvent.EventType.HIT, &"bao_counter_success_l3"), &"counter_special",
        "Counter hit has a dedicated presentation audio cue")
    t.equal(CombatFeedbackProfile.audio_cue_for_move(CombatEvent.EventType.HIT, &"pink_true_finisher_5"), &"finisher_ultimate",
        "Finisher hit has a dedicated presentation audio cue")
    var audio := CombatAudioPresenter.new()
    audio.present_event(CombatEvent.round_started(1, 1))
    t.equal(audio.last_cue, &"round_start", "Round start exposes its fallback audio hook")
    audio.present_event(CombatEvent.match_ended(2, RoundController.Participant.P1, 1))
    t.equal(audio.last_cue, &"victory", "Match end exposes the victory audio hook")
    audio.free()

func _test_shared_dedupe() -> void:
    var ledger := PresentationEventLedger.new()
    var vfx := CombatVfxPresenter.new()
    var audio := CombatAudioPresenter.new()
    var camera := BattleCameraController.new()
    var event := _event()
    if ledger.consume_once(event):
        vfx.present_event(event)
        audio.present_event(event)
        camera.present_event(event)
    if ledger.consume_once(event):
        vfx.present_event(event)
        audio.present_event(event)
        camera.present_event(event)
    t.equal(vfx.spawn_count, 1, "Duplicate HIT event spawns one VFX cue")
    t.equal(audio.cue_dispatch_count, 1, "Duplicate HIT event dispatches one audio cue")
    t.equal(camera.shake_request_count, 1, "Duplicate HIT event requests one camera shake")
    vfx.free()
    audio.free()
    camera.free()

func _test_camera_follow_and_reset() -> void:
    var generic := load("res://data/characters/generic_fighter.tres") as CharacterData
    var rush := load("res://data/characters/rush_grappler.tres") as CharacterData
    var battle := BattleSimulation.new()
    battle.configure(generic, rush, null, null, Vector2i(40000, 56000), Vector2i(80000, 56000))
    var camera := BattleCameraController.new()
    camera.configure(battle)
    t.equal(camera.position, Vector2(600, 560), "Camera follow midpoint derives from render positions only")
    camera.request_shake(8.0, 0.2)
    t.that(camera.shake_remaining_seconds > 0.0, "Camera presentation shake can be active independently")
    camera.reset_feedback()
    t.equal(camera.shake_remaining_seconds, 0.0, "Full presentation reset clears camera shake")
    camera.free()
