class_name GoldenPairSplitMoveTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const EXPECTED_MOVE_IDS: Array[StringName] = [
    &"stand_light",
    &"stand_heavy",
    &"crouch_low",
    &"air_attack",
    &"ground_throw",
    &"special_neutral",
    &"ultimate",
]
const CHARACTER_SPECIFIC_MOVE_IDS := {
    &"magic_orange_cat": [&"magic_circle_l1", &"magic_circle_l2", &"magic_circle_l3"],
    &"salad_cat": [&"salad_wave_l1", &"salad_wave_l2", &"salad_wave_l3"],
}

var t = ASSERT_HELPER.new()

func run_all() -> int:
    for character_id: StringName in CHARACTER_SPECIFIC_MOVE_IDS:
        _test_character_move_resources(character_id)
    print("\nGolden Pair split move tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_character_move_resources(character_id: StringName) -> void:
    var character := RosterRegistry.character_by_id(character_id)
    t.that(character != null and character.move_set != null, "%s package loads its move set" % String(character_id))
    if character == null or character.move_set == null:
        return
    t.equal(character.move_set.moves.size(), 10, "%s keeps all ten authored moves" % String(character_id))
    var expected_ids := EXPECTED_MOVE_IDS.duplicate()
    expected_ids.append_array(CHARACTER_SPECIFIC_MOVE_IDS[character_id])
    var actual_ids: Array[StringName] = []
    var expected_root := "res://content/characters/%s/gameplay/moves/" % String(character_id)
    for move: MoveData in character.move_set.moves:
        t.that(move != null, "%s move-set contains no null MoveData" % String(character_id))
        if move == null:
            continue
        actual_ids.append(move.id)
        t.that(move.resource_path.begins_with(expected_root), "%s is package-owned MoveData" % String(move.id))
    actual_ids.sort()
    expected_ids.sort()
    t.equal(actual_ids, expected_ids, "%s preserves canonical and mechanic-specific move IDs" % String(character_id))
