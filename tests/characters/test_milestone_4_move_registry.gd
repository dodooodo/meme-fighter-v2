# Responsibility: M4 per-fighter MoveRegistry isolation and immutable shared-resource regression suite.
class_name Milestone4MoveRegistryTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    _test_same_move_id_resolves_per_character()
    _test_registry_runtime_isolation()
    _test_meter_independence()
    _test_shared_generic_resource_is_not_runtime_mutated()
    print("\nM4 Move Registry tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(30000, BattleSimulation.GROUND_Y_UNITS), Vector2i(90000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _test_same_move_id_resolves_per_character() -> void:
    var g := MoveRegistry.new()
    var r := MoveRegistry.new()
    t.that(g.configure(generic.move_set), "Generic registry configures")
    t.that(r.configure(rush.move_set), "Rush registry configures")
    for move_id in [MoveIds.STAND_LIGHT, MoveIds.SPECIAL_NEUTRAL, MoveIds.ULTIMATE]:
        t.that(g.has_move(move_id) and r.has_move(move_id), "Both registries contain %s" % String(move_id))
        t.that(g.get_move(move_id) != r.get_move(move_id), "Same canonical %s resolves to distinct MoveData resources" % String(move_id))
    t.equal(g.get_move(MoveIds.STAND_LIGHT).damage, 50, "Generic STAND_LIGHT damage remains 50")
    t.equal(r.get_move(MoveIds.STAND_LIGHT).damage, 45, "Rush STAND_LIGHT damage is 45")
    t.equal(g.get_move(MoveIds.SPECIAL_NEUTRAL).startup_frames, 10, "Generic Special startup remains 10F")
    t.equal(r.get_move(MoveIds.SPECIAL_NEUTRAL).startup_frames, 8, "Rush Special startup is 8F")

func _test_registry_runtime_isolation() -> void:
    var battle := _battle(generic, rush)
    var generic_move := battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT)
    var rush_move := battle.fighter_b.move_registry.get_move(MoveIds.STAND_LIGHT)
    t.that(generic_move != rush_move, "Fighter-owned registries do not globally overwrite canonical IDs")
    t.that(battle.fighter_b.move_runner.start_move(rush_move), "Rush MoveRunner starts Rush Light")
    t.equal(battle.fighter_a.move_runner.current_move_id(), &"", "Rush runtime state does not affect Generic MoveRunner")
    t.equal(battle.fighter_b.move_runner.current_move, rush_move, "Rush runtime points at Rush MoveData")
    t.equal(battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT), generic_move, "Generic registry still resolves original Generic MoveData")

func _test_meter_independence() -> void:
    var battle := _battle(generic, rush)
    battle.fighter_a.meter.gain(8)
    t.equal(battle.fighter_a.meter.get_value(), 40, "Generic meter gains independently")
    t.equal(battle.fighter_b.meter.get_value(), 0, "Rush meter is unchanged by Generic gain")
    battle.fighter_b.meter.gain(18)
    t.equal(battle.fighter_b.meter.get_value(), 90, "Rush meter gains independently")
    t.equal(battle.fighter_a.meter.get_value(), 40, "Generic meter is unchanged by Rush gain")

func _test_shared_generic_resource_is_not_runtime_mutated() -> void:
    var battle := _battle(generic, generic)
    var shared := battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT)
    var original_damage := shared.damage
    var original_startup := shared.startup_frames
    t.that(battle.fighter_a.move_runner.start_move(shared), "P1 starts shared Generic Stand Light")
    battle.fighter_a.move_runner.finalize_tick(false)
    t.equal(battle.fighter_b.move_registry.get_move(MoveIds.STAND_LIGHT).damage, original_damage, "P1 runtime action does not mutate shared MoveData damage")
    t.equal(battle.fighter_b.move_registry.get_move(MoveIds.STAND_LIGHT).startup_frames, original_startup, "P1 runtime action does not mutate shared MoveData frame data")
