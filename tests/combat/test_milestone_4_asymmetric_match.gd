# Responsibility: M4 asymmetric Generic/Rush combat, same-frame trade, and per-attacker data proof.
class_name Milestone4AsymmetricMatchTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    _test_cross_character_light_damage()
    _test_same_frame_trade_uses_each_registry()
    _test_cross_character_throw_data()
    _test_mirror_match_configurations_still_construct()
    print("\nM4 Asymmetric Match tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData, ax: int = 50000, bx: int = 57000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _advance(battle: BattleSimulation, frames: int) -> void:
    for _i in range(frames):
        _tick(battle)

func _test_cross_character_light_damage() -> void:
    var generic_hits := _battle(generic, rush)
    _tick(generic_hits, InputFrame.with_light_press(1))
    _advance(generic_hits, 5)
    t.equal(generic_hits.fighter_b.combatant.hp, 4950, "Generic Light hits Rush using Generic damage 50")
    t.equal(generic_hits.fighter_a.meter.get_value(), 8, "Generic Light uses Generic +8 HIT meter")

    var rush_hits := _battle(rush, generic)
    _tick(rush_hits, InputFrame.with_light_press(1))
    _advance(rush_hits, 4)
    t.equal(rush_hits.fighter_b.combatant.hp, 4955, "Rush Light hits Generic using Rush damage 45")
    t.equal(rush_hits.fighter_a.meter.get_value(), 7, "Rush Light uses Rush +7 HIT meter")

func _test_same_frame_trade_uses_each_registry() -> void:
    var battle := _battle(generic, rush)
    # Start Rush one frame later so Generic 5F startup and Rush 4F startup become active on the same simulation frame.
    _tick(battle, InputFrame.with_light_press(1), InputFrame.neutral(1))
    _tick(battle, InputFrame.neutral(2), InputFrame.with_light_press(2))
    _advance(battle, 4)
    t.equal(battle.fighter_a.combatant.hp, 4955, "Asymmetric trade applies Rush 45 damage to Generic")
    t.equal(battle.fighter_b.combatant.hp, 4950, "Asymmetric trade applies Generic 50 damage to Rush")
    t.equal(battle.fighter_a.meter.get_value(), 9, "Asymmetric trade gives the authored Generic trade meter")
    t.equal(battle.fighter_b.meter.get_value(), 8, "Asymmetric trade gives the authored Rush trade meter")

func _guard(frame: int) -> InputFrame:
    var bit := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, 0, bit, bit, 0)

func _test_cross_character_throw_data() -> void:
    var generic_throw := _battle(generic, rush)
    _tick(generic_throw, InputFrame.with_heavy_press(1, 1), _guard(1))
    for _i in range(5):
        var f := generic_throw.frame_number + 1
        _tick(generic_throw, null, InputFrame.new(f, 0, 0, InputFrame.InputButton.GUARD, 0, 0))
    for _i in range(6):
        _tick(generic_throw, null, InputFrame.new(generic_throw.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD, 0, 0))
    t.equal(generic_throw.fighter_b.combatant.hp, 4880, "Generic throws Rush for Generic 120 damage")
    t.equal(generic_throw.fighter_a.meter.get_value(), 15, "Generic throw rewards Generic +15")

    var rush_throw := _battle(rush, generic)
    _tick(rush_throw, InputFrame.with_heavy_press(1, 1), _guard(1))
    for _i in range(5):
        var f := rush_throw.frame_number + 1
        _tick(rush_throw, null, InputFrame.new(f, 0, 0, InputFrame.InputButton.GUARD, 0, 0))
    for _i in range(6):
        _tick(rush_throw, null, InputFrame.new(rush_throw.frame_number + 1, 0, 0, InputFrame.InputButton.GUARD, 0, 0))
    t.equal(rush_throw.fighter_b.combatant.hp, 4850, "Rush throws Generic for Rush 150 damage")
    t.equal(rush_throw.fighter_a.meter.get_value(), 18, "Rush throw rewards Rush +18")

func _test_mirror_match_configurations_still_construct() -> void:
    for pair in [[generic, generic], [rush, rush], [generic, rush], [rush, generic]]:
        var battle := _battle(pair[0], pair[1], 30000, 90000)
        t.that(battle.fighter_a.data == pair[0] and battle.fighter_b.data == pair[1], "BattleSimulation supports requested character pair without combat branching")
        t.that(battle.fighter_a.move_registry.has_move(MoveIds.STAND_LIGHT) and battle.fighter_b.move_registry.has_move(MoveIds.STAND_LIGHT), "Both pair registries resolve canonical Stand Light")
