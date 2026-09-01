# Gate 3 Training/Debug tests. Tooling uses the same authoritative simulation and remains opt-in/read-only outside training controls.
class_name Gate3TrainingDebugTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_training_controls()
    _test_dummy_modes()
    _test_mechanic_controls()
    _test_debug_data_availability()
    print("\nGate 3 Training/Debug tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _training_battle() -> BattleSimulation:
    var pink := RosterRegistry.character_by_id(&"pink_star")
    var niu := RosterRegistry.character_by_id(&"niu_lai")
    var rules := load("res://data/match_rules/training_match_rules.tres") as MatchRulesData
    var battle := BattleSimulation.new()
    battle.configure(pink, niu, null, null, Vector2i(36000, BattleSimulation.GROUND_Y_UNITS), Vector2i(72000, BattleSimulation.GROUND_Y_UNITS), rules)
    return battle

func _dummy_battle(dummy: TrainingDummyInputSource) -> BattleSimulation:
    var rules := load("res://data/match_rules/training_match_rules.tres") as MatchRulesData
    var battle := BattleSimulation.new()
    battle.configure(RosterRegistry.character_by_id(&"pink_star"), RosterRegistry.character_by_id(&"niu_lai"), null, dummy, Vector2i(36000, BattleSimulation.GROUND_Y_UNITS), Vector2i(72000, BattleSimulation.GROUND_Y_UNITS), rules)
    dummy.bind_context(battle.fighter_b)
    return battle

func _status_training_battle() -> BattleSimulation:
    var rules := load("res://data/match_rules/training_match_rules.tres") as MatchRulesData
    var battle := BattleSimulation.new()
    battle.configure(RosterRegistry.character_by_id(&"sauce_stubble_dog"), RosterRegistry.character_by_id(&"alien_meow"), null, null, Vector2i(36000, BattleSimulation.GROUND_Y_UNITS), Vector2i(72000, BattleSimulation.GROUND_Y_UNITS), rules)
    return battle

func _test_training_controls() -> void:
    var battle := _training_battle()
    var controller := TrainingController.new()
    controller.configure(battle, true)
    t.that(battle.fighter_a.combatant.training_infinite_hp and battle.fighter_b.combatant.training_infinite_hp, "Training enables Infinite HP through authoritative Combatant training flag")
    t.that(battle.fighter_a.meter.training_infinite_meter and battle.fighter_b.meter.training_infinite_meter, "Training enables Infinite Meter through MeterComponent flag")
    t.that(controller.set_meter(1, 37), "Training can set meter")
    t.equal(battle.fighter_a.meter.get_value(), 37, "Training meter control updates authoritative MeterComponent")
    var old_a := battle.fighter_a.movement_motor.sim_position
    battle.fighter_a.movement_motor.sim_position.x += 5000
    controller.reset_positions()
    t.equal(battle.fighter_a.movement_motor.sim_position, old_a, "Training position reset returns canonical start position")

func _test_dummy_modes() -> void:
    var dummy := TrainingDummyInputSource.new()
    var expected := ["STAND", "CROUCH", "STAND_GUARD", "CROUCH_GUARD", "GUARD_AFTER_FIRST_HIT", "JUMP", "BACKSTEP"]
    t.equal(TrainingDummyInputSource.DummyMode.size(), 7, "Training exposes seven canonical dummy policies")
    for mode in range(TrainingDummyInputSource.DummyMode.size()):
        dummy.set_dummy_mode(mode)
        t.equal(dummy.mode_name(), expected[mode], "Training dummy mode resolves: %s" % expected[mode])
    dummy.set_dummy_mode(TrainingDummyInputSource.DummyMode.CROUCH_GUARD)
    var crouch_guard := dummy.sample(1)
    t.equal(crouch_guard.direction_y, -1, "Crouch Guard dummy holds Down")
    t.that(crouch_guard.is_held(InputFrame.InputButton.GUARD), "Crouch Guard dummy holds Guard")
    dummy = TrainingDummyInputSource.new()
    var jump_battle := _dummy_battle(dummy)
    dummy.set_dummy_mode(TrainingDummyInputSource.DummyMode.JUMP)
    jump_battle.sample_and_simulate_frame()
    t.that(jump_battle.fighter_b.is_airborne(), "Training Dummy Jump executes through real Fighter grounded query")
    dummy.set_dummy_mode(TrainingDummyInputSource.DummyMode.STAND)
    for _frame in range(180):
        if jump_battle.fighter_b.is_grounded(): break
        jump_battle.sample_and_simulate_frame()
    t.that(jump_battle.fighter_b.is_grounded(), "Training Dummy returns to grounded after real landing")
    dummy = TrainingDummyInputSource.new()
    var backstep_battle := _dummy_battle(dummy)
    var start_x := (backstep_battle.fighter_b.capture_combat_read()["position_units"] as Vector2i).x
    dummy.set_dummy_mode(TrainingDummyInputSource.DummyMode.BACKSTEP)
    for _frame in range(3): backstep_battle.sample_and_simulate_frame()
    var end_x := (backstep_battle.fighter_b.capture_combat_read()["position_units"] as Vector2i).x
    t.that(end_x != start_x or int(backstep_battle.fighter_b.capture_combat_read()["state_id"]) == FighterStateMachine.State.BACKSTEP, "Training Dummy Backstep executes through stable facing observation")

func _test_mechanic_controls() -> void:
    var battle := _training_battle()
    var controller := TrainingController.new()
    controller.configure(battle, true)
    t.that(controller.set_resource(1, &"face_actions", 3), "Training generic mechanic control sets Pink Face Actions")
    t.equal(battle.fighter_a.resources.get_value(&"face_actions"), 3, "Pink Face Actions training value is authoritative resource state")
    t.that(controller.activate_mode(1, &"true_face"), "Training generic mode control activates Pink True Face")
    t.equal(battle.fighter_a.mode.active_mode_id, &"true_face", "True Face mode state is visible to combat/debug systems")
    t.that(controller.set_resource(2, &"courage", 2), "Training generic resource control sets Niu Courage")
    t.equal(battle.fighter_b.resources.get_value(&"courage"), 2, "Niu Courage training value is authoritative resource state")
    var status_battle := _status_training_battle()
    controller.configure(status_battle, true)
    t.that(controller.toggle_status(1, &"sauce"), "Training status command applies authored Sauce through canonical component")
    t.that(status_battle.fighter_a.has_status(&"sauce"), "Training status apply is visible through Fighter read API")
    t.that(controller.toggle_status(1, &"sauce"), "Training status command removes authored Sauce through canonical component")
    t.that(not status_battle.fighter_a.has_status(&"sauce"), "Training status removal updates authoritative StatusEffectComponent")

func _test_debug_data_availability() -> void:
    var battle := _training_battle()
    var overlay := DebugOverlay.new()
    var line := overlay._fighter_line(battle.fighter_a, battle.frame_number)
    for token in ["State=", "Move=", "Adv=", "HP=", "Meter=", "Combo=", "Charge=", "ThrowProtect=", "Mode=", "Res=", "Status=", "Stars="]:
        t.that(token in line, "Debug overlay exposes authoritative diagnostic field: %s" % token)
    var status_battle := _status_training_battle()
    var status_fighter := status_battle.fighter_a
    t.that(status_fighter.statuses.apply_defined(&"sauce"), "Debug fixture applies authored Sauce")
    t.that(status_fighter.statuses.apply_defined(&"signal_mark"), "Debug fixture applies authored Signal Mark")
    var status_line := overlay._fighter_line(status_fighter, status_battle.frame_number)
    t.that("sauce:" in status_line and "signal_mark:" in status_line, "DebugOverlay renders multiple statuses from copied Fighter observation")
    var debugger := HitboxDebugger.new()
    debugger.set_simulation(battle)
    t.equal(debugger.simulation, battle, "Hitbox debugger observes the authoritative BattleSimulation")
    t.that(FrameAdvantageCalculator.on_block(battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT)) is int, "Frame advantage debug derives from MoveData timing")
    overlay.free()
    debugger.free()
