extends SceneTree

const SPAWN_SUITE := preload("res://tests/match/test_battle_spawn_ownership.gd")
const ROUND_FLOW_SUITE := preload("res://tests/match/test_milestone_6_round_flow.gd")
const TRAINING_SUITE := preload("res://tests/match/test_milestone_6_training.gd")
const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")

var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    failures += SPAWN_SUITE.new().run_all()
    failures += ROUND_FLOW_SUITE.new().run_all()
    failures += TRAINING_SUITE.new().run_all()
    await _test_real_battle_scene_positions()
    print("\nPhase 4 spawn runtime: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(0 if failures == 0 else 1)

func _test_real_battle_scene_positions() -> void:
    var scene := BATTLE_SCENE.instantiate() as BattleScene
    _check(scene != null, "Real BattleScene instantiates for spawn ownership smoke")
    if scene == null:
        return
    scene.character_a_data = RosterRegistry.character_by_id(&"doge")
    scene.character_b_data = RosterRegistry.character_by_id(&"alien_meow")
    scene.character_a_presentation = RosterRegistry.presentation_by_id(&"doge")
    scene.character_b_presentation = RosterRegistry.presentation_by_id(&"alien_meow")
    root.add_child(scene)
    await process_frame
    var battle := scene.simulation
    _check(battle != null, "Real BattleScene completes _ready and owns a simulation")
    if battle != null:
        var p1 := battle.configured_start_position(1)
        var p2 := battle.configured_start_position(2)
        _check(battle.fighter_a.data == RosterRegistry.character_by_id(&"doge"), "Real BattleScene keeps Doge CharacterData")
        _check(battle.fighter_b.data == RosterRegistry.character_by_id(&"alien_meow"), "Real BattleScene keeps Alien Meow CharacterData")
        _check(battle.fighter_a.movement_motor.sim_position == p1, "Real BattleScene P1 position equals simulation-configured start")
        _check(battle.fighter_b.movement_motor.sim_position == p2, "Real BattleScene P2 position equals simulation-configured start")
        _check(p1.x == BattleSimulation.P1_START_X_UNITS and p2.x == BattleSimulation.P2_START_X_UNITS, "Real BattleScene uses canonical standard start coordinates")
    root.remove_child(scene)
    scene.free()

func _check(condition: bool, label: String) -> void:
    if condition:
        print("[PASS] %s" % label)
        return
    failures += 1
    push_error("[FAIL] %s" % label)
