# Responsibility: Phase 4 standard/configured spawn ownership and reset invariants.
class_name BattleSpawnOwnershipTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var doge: CharacterData
var alien: CharacterData

func run_all() -> int:
    doge = RosterRegistry.character_by_id(&"doge")
    alien = RosterRegistry.character_by_id(&"alien_meow")
    _test_standard_offsets_and_initial_positions()
    _test_training_reset_uses_custom_configured_starts()
    _test_snapshot_restore_does_not_redefine_configured_starts()
    print("\nPhase 4 spawn ownership tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_standard_offsets_and_initial_positions() -> void:
    var battle := BattleSimulation.new()
    battle.configure_standard(doge, alien)
    var p1 := battle.configured_start_position(1)
    var p2 := battle.configured_start_position(2)
    var unit := SimulationUnits.DESIGN_UNIT_TO_SIM_UNITS
    t.equal(p1.x - BattleSimulation.STAGE_LEFT_UNITS, 6 * unit, "Standard P1 start is stage-left + 6 design units")
    t.equal(p2.x - BattleSimulation.STAGE_LEFT_UNITS, 12 * unit, "Standard P2 start is stage-left + 12 design units")
    t.equal(p2.x - p1.x, 6 * unit, "Standard fighter separation is 6 design units")
    t.equal(battle.fighter_a.movement_motor.sim_position, p1, "Simulation initializes P1 at its configured start")
    t.equal(battle.fighter_b.movement_motor.sim_position, p2, "Simulation initializes P2 at its configured start")

func _test_training_reset_uses_custom_configured_starts() -> void:
    var battle := BattleSimulation.new()
    var custom_a := Vector2i(BattleSimulation.STAGE_LEFT_UNITS + 4 * SimulationUnits.DESIGN_UNIT_TO_SIM_UNITS, BattleSimulation.GROUND_Y_UNITS)
    var custom_b := Vector2i(BattleSimulation.STAGE_LEFT_UNITS + 14 * SimulationUnits.DESIGN_UNIT_TO_SIM_UNITS, BattleSimulation.GROUND_Y_UNITS)
    battle.configure(doge, alien, null, null, custom_a, custom_b, MatchRulesData.training_defaults())
    var controller := TrainingController.new()
    controller.configure(battle, true)
    battle.fighter_a.movement_motor.sim_position.x += 9000
    battle.fighter_b.movement_motor.sim_position.x -= 7000
    controller.reset_positions()
    t.equal(battle.configured_start_position(1), custom_a, "Training custom P1 start remains simulation-owned configuration")
    t.equal(battle.configured_start_position(2), custom_b, "Training custom P2 start remains simulation-owned configuration")
    t.equal(battle.fighter_a.movement_motor.sim_position, custom_a, "TrainingController resets P1 to simulation-configured custom start")
    t.equal(battle.fighter_b.movement_motor.sim_position, custom_b, "TrainingController resets P2 to simulation-configured custom start")

func _test_snapshot_restore_does_not_redefine_configured_starts() -> void:
    var battle := BattleSimulation.new()
    var custom_a := Vector2i(BattleSimulation.STAGE_LEFT_UNITS + 5 * SimulationUnits.DESIGN_UNIT_TO_SIM_UNITS, BattleSimulation.GROUND_Y_UNITS)
    var custom_b := Vector2i(BattleSimulation.STAGE_LEFT_UNITS + 13 * SimulationUnits.DESIGN_UNIT_TO_SIM_UNITS, BattleSimulation.GROUND_Y_UNITS)
    battle.configure(doge, alien, null, null, custom_a, custom_b)
    battle.fighter_a.movement_motor.sim_position.x += 3000
    battle.fighter_b.movement_motor.sim_position.x -= 3000
    var snapshot := battle.capture_state()
    battle.fighter_a.movement_motor.sim_position.x += 5000
    battle.fighter_b.movement_motor.sim_position.x -= 5000
    t.that(battle.restore_state(snapshot), "Gameplay snapshot restores successfully before configured reset")
    battle.reset_full_match()
    t.equal(battle.configured_start_position(1), custom_a, "Snapshot restore leaves configured P1 start unchanged")
    t.equal(battle.configured_start_position(2), custom_b, "Snapshot restore leaves configured P2 start unchanged")
    t.equal(battle.fighter_a.movement_motor.sim_position, custom_a, "Post-snapshot full reset returns P1 to original configured start")
    t.equal(battle.fighter_b.movement_motor.sim_position, custom_b, "Post-snapshot full reset returns P2 to original configured start")
