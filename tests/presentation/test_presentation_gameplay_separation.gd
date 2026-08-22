# M7 presentation must remain a one-way observer and leave gameplay hash unchanged.
class_name PresentationGameplaySeparationTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var generic: CharacterData
var zone_p: CharacterPresentationData
var generic_p: CharacterPresentationData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    zone_p = load("res://presentation/characters/zone_fighter_presentation.tres") as CharacterPresentationData
    generic_p = load("res://presentation/characters/generic_fighter_presentation.tres") as CharacterPresentationData
    _test_hash_equal_with_read_only_presentation()
    _test_headless_round_projectile_replay_surface()
    print("\nM7 gameplay separation tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _p1(frame: int) -> InputFrame:
    return InputFrame.with_special_press(frame) if frame in [1, 50] else InputFrame.neutral(frame)

func _test_hash_equal_with_read_only_presentation() -> void:
    var a := BattleSimulation.new()
    var b := BattleSimulation.new()
    var rules_a := MatchRulesData.versus_defaults()
    var rules_b := MatchRulesData.versus_defaults()
    rules_a.round_timer_frames = 120
    rules_b.round_timer_frames = 120
    a.configure(zone, generic, null, null, Vector2i(50000, 56000), Vector2i(62000, 56000), rules_a)
    b.configure(zone, generic, null, null, Vector2i(50000, 56000), Vector2i(62000, 56000), rules_b)
    var root := Node.new()
    var fp1 := FighterPresentationController.new()
    var fp2 := FighterPresentationController.new()
    var projectile_presenter := ProjectileVisualPresenter.new()
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(root)
    root.add_child(fp1)
    root.add_child(fp2)
    root.add_child(projectile_presenter)
    fp1.configure(b.fighter_a, zone_p, root)
    fp2.configure(b.fighter_b, generic_p, root)
    var presentations: Array[CharacterPresentationData] = [zone_p, generic_p]
    projectile_presenter.configure(b, presentations)
    for frame in range(1, 121):
        var p1 := _p1(frame)
        var p2 := InputFrame.neutral(frame)
        a.simulate_frame(p1, p2)
        b.simulate_frame(p1, p2)
        fp1.sync_from_simulation()
        fp2.sync_from_simulation()
        projectile_presenter.sync_from_simulation()
    t.equal(b.state_signature(), a.state_signature(), "Identical battles with/without presentation observers finish with identical BattleStateHash")
    scene_tree.root.remove_child(root)
    root.free()

func _test_headless_round_projectile_replay_surface() -> void:
    var battle := BattleSimulation.new()
    battle.configure(zone, generic)
    var recorder := ReplayRecorder.new()
    recorder.begin_recording(&"versus", zone.id, generic.id, 0)
    battle.set_replay_recorder(recorder)
    for frame in range(1, 40):
        battle.simulate_frame(_p1(frame), InputFrame.neutral(frame))
    t.that(battle.frame_number == 39, "Headless BattleSimulation still advances without CharacterPresentationData")
    t.that(battle.projectile_system.next_projectile_instance_serial > 1, "Headless simulation still owns projectile gameplay")
    t.equal(recorder.replay_data().frame_count(), 39, "Replay recording remains independent of presentation nodes")
