class_name M9PUltimateScreenPackTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var battle := BattleSimulation.new()
    battle.configure(load("res://data/characters/generic_fighter.tres") as CharacterData, load("res://data/characters/zone_fighter.tres") as CharacterData)
    var data := (load("res://presentation/characters/generic_fighter_presentation.tres") as CharacterPresentationData).duplicate(true) as CharacterPresentationData
    var binding := UltimatePresentationBinding.new()
    binding.ultimate_id = &"ultimate"
    binding.background_scene = load("res://presentation/ultimates/ultimate_screen_visual.tscn") as PackedScene
    data.ultimate_bindings = [binding]
    var presenter := UltimateScreenPresenter.new()
    var presentations: Array[CharacterPresentationData] = [data]
    presenter.configure(battle, presentations)
    var event := CombatEvent.move_started(10, battle.fighter_a.fighter_id, &"ultimate", 1)
    presenter.present_event(event)
    t.equal(presenter.active_count(), 1, "Ultimate MOVE_STARTED may spawn one screen-space background")
    presenter.free()
    print("\nM9P UltimateScreenPack: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
