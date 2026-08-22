# Golden Pair roster resources must never fall back to generic idle/attack keys.
class_name GoldenPairPresentationBindingTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const STATE_KEYS := [
    &"idle", &"walk_forward", &"walk_back", &"crouch", &"jump", &"landing",
    &"guard_stand", &"guard_crouch", &"hitstun", &"blockstun", &"thrown",
    &"knockdown", &"getup", &"ko", &"dash_forward", &"backstep", &"charge",
]
const MOVE_KEYS := [
    &"stand_light", &"stand_heavy", &"crouch_low", &"air_attack", &"ground_throw",
    &"special_neutral", &"ultimate",
]

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_required_bindings(&"salad_cat")
    _test_required_bindings(&"magic_orange_cat")
    _test_magic_charge_variants()
    print("\nGolden Pair presentation binding tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _presentation(character_id: StringName) -> CharacterPresentationData:
    return RosterRegistry.presentation_by_id(character_id)

func _test_required_bindings(character_id: StringName) -> void:
    var presentation := _presentation(character_id)
    t.that(presentation != null, "%s roster presentation resource loads" % String(character_id))
    if presentation == null:
        return
    t.equal(presentation.character_id, character_id, "%s presentation identity matches roster ID" % String(character_id))
    for state_key: StringName in STATE_KEYS:
        t.equal(presentation.animation_for_state(state_key, &""), _expected_state_key(state_key), "%s explicitly binds state %s" % [String(character_id), String(state_key)])
    for move_key: StringName in MOVE_KEYS:
        t.equal(presentation.animation_for_move(move_key, &""), move_key, "%s explicitly binds move %s" % [String(character_id), String(move_key)])

func _test_magic_charge_variants() -> void:
    var presentation := _presentation(&"magic_orange_cat")
    if presentation == null:
        return
    for move_id: StringName in [&"special_neutral_l2", &"special_neutral_l3"]:
        t.equal(presentation.animation_for_move(move_id, &""), &"special_neutral", "Magic Orange Cat explicitly binds %s" % String(move_id))

func _expected_state_key(state_key: StringName) -> StringName:
    return &"special_neutral" if state_key == &"charge" else state_key
