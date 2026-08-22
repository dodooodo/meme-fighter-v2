# M7 CharacterPresentationData identity/binding validation.
class_name CharacterPresentationDataTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_three_resources_match_gameplay_ids()
    _test_canonical_move_bindings_and_production_specials()
    _test_duplicate_bindings_rejected()
    print("\nM7 CharacterPresentationData tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_three_resources_match_gameplay_ids() -> void:
    for id_value in [&"generic_fighter", &"rush_grappler", &"zone_fighter"]:
        var gameplay := load("res://data/characters/%s.tres" % String(id_value)) as CharacterData
        var presentation := load("res://presentation/characters/%s_presentation.tres" % String(id_value)) as CharacterPresentationData
        t.that(gameplay != null and presentation != null, "%s gameplay/presentation resources load" % String(id_value))
        t.equal(presentation.character_id, gameplay.id, "%s presentation ID matches CharacterData.id" % String(id_value))
        t.that(not presentation.display_name.is_empty(), "%s presentation display name is non-empty" % String(id_value))
        t.equal(presentation.validate(gameplay.id).size(), 0, "%s presentation resource validates" % String(id_value))

func _test_canonical_move_bindings_and_production_specials() -> void:
    var expected := [&"stand_light", &"stand_heavy", &"crouch_low", &"air_attack", &"ground_throw", &"special_neutral", &"ultimate"]
    var specials: Dictionary = {}
    for id_value in [&"generic_fighter", &"rush_grappler", &"zone_fighter"]:
        var presentation := load("res://presentation/characters/%s_presentation.tres" % String(id_value)) as CharacterPresentationData
        presentation.rebuild_cache()
        for move_id in expected:
            t.that(presentation.animation_for_move(move_id, &"") != &"", "%s binds canonical move %s" % [String(id_value), String(move_id)])
        specials[id_value] = presentation.animation_for_move(&"special_neutral")
    t.equal(specials[&"generic_fighter"], &"special_neutral", "Salad Cat uses canonical SPECIAL_NEUTRAL production animation key")
    t.equal(specials[&"zone_fighter"], &"special_neutral", "Magic Orange Cat uses canonical SPECIAL_NEUTRAL production animation key")
    t.that(specials[&"rush_grappler"] != &"", "Rush Grappler retains its existing valid presentation mapping")

func _test_duplicate_bindings_rejected() -> void:
    var data := CharacterPresentationData.new()
    data.character_id = &"test"
    data.display_name = "Test"
    var a := MovePresentationBinding.new()
    a.move_id = &"stand_light"
    a.animation_key = &"a"
    var b := MovePresentationBinding.new()
    b.move_id = &"stand_light"
    b.animation_key = &"b"
    data.move_bindings = [a, b]
    t.that(data.validate().has("duplicate move binding: stand_light"), "Duplicate MovePresentationBinding is rejected")
    var s1 := StatePresentationBinding.new()
    s1.state_key = &"idle"
    s1.animation_key = &"idle_a"
    var s2 := StatePresentationBinding.new()
    s2.state_key = &"idle"
    s2.animation_key = &"idle_b"
    data.move_bindings = []
    data.state_bindings = [s1, s2]
    t.that(data.validate().has("duplicate state binding: idle"), "Duplicate StatePresentationBinding is rejected")
