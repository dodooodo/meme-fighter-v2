# M7 VFX/audio/camera one-shot dispatch through shared event ledger.
class_name FeedbackPresenterTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_shared_dedupe()
    _test_camera_follow_and_reset()
    print("\nM7 feedback presenter tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _event() -> CombatEvent:
    var result := HitResult.new()
    result.attacker_id = 1
    result.defender_id = 2
    result.move_id = &"stand_heavy"
    result.attack_instance_id = 9
    result.hit_position = Vector2(600, 450)
    return CombatEvent.hit(20, result, 1000, 900)

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
