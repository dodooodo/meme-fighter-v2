class_name M9PModeVisualSwapTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var battle := BattleSimulation.new()
    battle.configure(load("res://data/characters/rush_grappler.tres") as CharacterData, load("res://data/characters/generic_fighter.tres") as CharacterData)
    var source := load("res://presentation/characters/rush_grappler_presentation.tres") as CharacterPresentationData
    var data := source.duplicate(true) as CharacterPresentationData
    var binding := ModePresentationBinding.new()
    binding.mode_id = &"super_doge"
    binding.fighter_visual_scene = load("res://presentation/visuals/greybox_fighter_visual.tscn") as PackedScene
    binding.visual_scale = 1.2
    data.mode_bindings = [binding]
    var parent := Node2D.new()
    var controller := FighterPresentationController.new()
    var gameplay_state := battle.fighter_a.state_machine.state
    var gameplay_position := battle.fighter_a.movement_motor.sim_position
    t.that(controller.configure(battle.fighter_a, data, parent), "Controller configures BASE visual")
    t.that(controller.apply_authoritative_mode_id(&"super_doge"), "Presentation swaps to bound mode visual")
    t.equal(controller.active_mode_id, &"super_doge", "Presentation records active mode id")
    t.equal(battle.fighter_a.state_machine.state, gameplay_state, "Mode visual swap does not change gameplay HFSM")
    t.equal(battle.fighter_a.movement_motor.sim_position, gameplay_position, "Mode visual swap does not move gameplay Fighter")
    controller.free()
    parent.free()
    print("\nM9P ModeVisualSwap: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
