# Responsibility: M4 stable character identity, movement configuration, and MoveSet completeness regression suite.
class_name Milestone4CharacterDataTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    _test_character_identity_contract()
    _test_move_set_completeness()
    _test_rush_movement_profile()
    _test_generic_regression_values()
    print("\nM4 Character Data tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _required_move_ids() -> Array[StringName]:
    return [MoveIds.STAND_LIGHT, MoveIds.STAND_HEAVY, MoveIds.CROUCH_LOW, MoveIds.AIR_ATTACK, MoveIds.GROUND_THROW, MoveIds.SPECIAL_NEUTRAL, MoveIds.ULTIMATE]

func _test_character_identity_contract() -> void:
    t.that(generic != null and rush != null, "Both M4 CharacterData resources load")
    t.equal(generic.id, &"generic_fighter", "Generic stable CharacterData.id is generic_fighter")
    t.equal(rush.id, &"rush_grappler", "Rush stable CharacterData.id is rush_grappler")
    t.that(generic.id != &"" and rush.id != &"", "Character IDs are non-empty")
    t.that(generic.id != rush.id, "Character IDs are unique")
    t.equal(generic.max_hp, rush.max_hp, "M4 does not use HP difference for character identity")

func _test_move_set_completeness() -> void:
    for character in [generic, rush]:
        var registry := MoveRegistry.new()
        t.that(character.move_set != null, "%s has MoveSetData" % String(character.id))
        t.that(registry.configure(character.move_set), "%s MoveSet validates without duplicate/null IDs" % String(character.id))
        for move_id in _required_move_ids():
            t.that(registry.has_move(move_id), "%s contains canonical move %s" % [String(character.id), String(move_id)])
            t.that(registry.get_move(move_id) != null, "%s canonical move %s resolves non-null" % [String(character.id), String(move_id)])

func _test_rush_movement_profile() -> void:
    t.equal(rush.walk_forward_units_per_tick, 345, "Rush forward walk is rounded generic x1.15")
    t.equal(rush.walk_back_units_per_tick, 252, "Rush back walk is rounded generic x1.05")
    t.equal(rush.jump_velocity_y_units_per_tick, -1350, "Rush jump velocity")
    t.equal(rush.gravity_y_units_per_tick2, 85, "Rush gravity")
    t.equal(rush.max_fall_speed_y_units_per_tick, 1850, "Rush max fall speed")
    t.equal(rush.air_forward_units_per_tick, 270, "Rush air forward")
    t.equal(rush.air_back_units_per_tick, 225, "Rush air back")
    t.equal(rush.landing_recovery_frames, 2, "Rush landing recovery is 2F")
    t.equal(rush.dash_move_frames, 7, "Rush forward dash movement is 7F")
    t.equal(rush.dash_speed_units_per_tick, 1050, "Rush forward dash speed")
    t.equal(rush.dash_recovery_frames, 3, "Rush forward dash recovery is 3F")
    t.equal(rush.backstep_move_frames, 6, "Rush backstep movement is 6F")
    t.equal(rush.backstep_speed_units_per_tick, 850, "Rush backstep speed")
    t.equal(rush.backstep_recovery_frames, 5, "Rush backstep recovery is 5F")

func _test_generic_regression_values() -> void:
    t.equal(generic.walk_forward_units_per_tick, 300, "Generic forward walk remains 300")
    t.equal(generic.walk_back_units_per_tick, 240, "Generic back walk remains 240")
    t.equal(generic.jump_velocity_y_units_per_tick, -1400, "Generic jump remains -1400")
    t.equal(generic.gravity_y_units_per_tick2, 80, "Generic gravity remains 80")
    t.equal(generic.air_forward_units_per_tick, 240, "Generic air forward remains 240")
    t.equal(generic.air_back_units_per_tick, 210, "Generic air back remains 210")
    t.equal(generic.landing_recovery_frames, 3, "Generic landing remains 3F")
    t.equal(generic.dash_move_frames, 8, "Generic dash movement remains 8F")
    t.equal(generic.dash_speed_units_per_tick, 900, "Generic dash speed remains 900")
    t.equal(generic.dash_recovery_frames, 4, "Generic dash recovery remains 4F")
    t.equal(generic.backstep_move_frames, 7, "Generic backstep movement remains 7F")
    t.equal(generic.backstep_speed_units_per_tick, 800, "Generic backstep speed remains 800")
    t.equal(generic.backstep_recovery_frames, 6, "Generic backstep recovery remains 6F")
