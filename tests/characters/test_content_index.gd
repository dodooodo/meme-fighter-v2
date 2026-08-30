class_name ContentIndexTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const GOLDEN_PAIR_MANIFESTS: Array[String] = [
    "res://content/characters/magic_orange_cat/character_manifest.tres",
    "res://content/characters/salad_cat/character_manifest.tres",
]

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_shipped_packages_have_no_errors()
    _test_allowlist_downgrades_unbound_moves()
    _test_missing_animation_key_is_an_error()
    _test_orphan_animations_are_warnings_only()
    _test_variant_gap_is_an_error()
    _test_unconditional_fallback_covers_gaps()
    print("\nContentIndex tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_shipped_packages_have_no_errors() -> void:
    var index := _index(_golden_pair(), CharacterValidator.load_unbound_allowlist())
    t.equal(index.issues(ContentIndex.SEVERITY_ERROR).size(), 0,
        "Shipped Golden Pair packages produce no error-severity content issues")

func _test_allowlist_downgrades_unbound_moves() -> void:
    var without_allowlist := _index(_golden_pair(), {})
    var unbound := _issues_with_code(without_allowlist, "move.unbound")
    t.that(unbound.size() > 0,
        "Unbound moves are errors when absent from the allowlist")

    var with_allowlist := _index(_golden_pair(), CharacterValidator.load_unbound_allowlist())
    t.equal(_issues_with_code(with_allowlist, "move.unbound").size(), 0,
        "Allowlisted unbound moves raise no error")
    t.equal(_issues_with_code(with_allowlist, "move.unbound_allowlisted").size(), unbound.size(),
        "Allowlisted unbound moves are still reported as warnings")

func _test_missing_animation_key_is_an_error() -> void:
    var manifest := _duplicated_manifest("res://content/characters/salad_cat/character_manifest.tres")
    manifest.presentation_resource.move_bindings[0].animation_key = &"animation_that_does_not_exist"
    var index := _index([manifest], CharacterValidator.load_unbound_allowlist())
    t.that(_issues_with_code(index, "move.animation_missing").size() > 0,
        "A binding pointing at an absent SpriteFrames animation is an error")

func _test_orphan_animations_are_warnings_only() -> void:
    var manifest := _duplicated_manifest("res://content/characters/salad_cat/character_manifest.tres")
    # Dropping every state binding orphans the movement and reaction animations.
    # Dropping just one would not: several state animations are also reachable
    # through a move binding.
    manifest.presentation_resource.state_bindings = []
    var index := _index([manifest], CharacterValidator.load_unbound_allowlist())
    var orphans := _issues_with_code(index, "animation.orphan")
    t.that(orphans.size() > 0, "Unreferenced built animations are reported")
    for issue: Dictionary in orphans:
        t.equal(issue["severity"], ContentIndex.SEVERITY_WARNING,
            "Orphaned built art never fails CI")

func _test_variant_gap_is_an_error() -> void:
    if not _supports_resource_variants():
        return
    var index := _index([_resource_variant_manifest(false)], {})
    t.that(_issues_with_code(index, "move.variant_gap").size() > 0,
        "Conditioned bindings that leave a resource value uncovered are an error")

func _test_unconditional_fallback_covers_gaps() -> void:
    if not _supports_resource_variants():
        return
    var index := _index([_resource_variant_manifest(true)], {})
    t.equal(_issues_with_code(index, "move.variant_gap").size(), 0,
        "An unconditional binding covers every otherwise-uncovered resource value")

# Resource-conditioned bindings are a newer presentation schema. These two cases
# only mean something once MovePresentationBinding carries the condition fields.
func _supports_resource_variants() -> bool:
    return MovePresentationBinding.new().get("resource_id") != null

# --- helpers -----------------------------------------------------------------

func _index(manifests: Array[CharacterManifest], allowlist: Dictionary) -> ContentIndex:
    var index := ContentIndex.new()
    index.build(manifests, allowlist)
    return index

func _golden_pair() -> Array[CharacterManifest]:
    var manifests: Array[CharacterManifest] = []
    for path: String in GOLDEN_PAIR_MANIFESTS:
        manifests.append(load(path) as CharacterManifest)
    return manifests

# Deep copy so a mutation for one assertion cannot leak into the shared resource
# cache and corrupt another suite.
func _duplicated_manifest(path: String) -> CharacterManifest:
    var manifest := (load(path) as CharacterManifest).duplicate(true) as CharacterManifest
    manifest.presentation_resource = manifest.presentation_resource.duplicate(true) as CharacterPresentationData
    var bindings: Array[MovePresentationBinding] = []
    for binding: MovePresentationBinding in manifest.presentation_resource.move_bindings:
        bindings.append(binding.duplicate(true) as MovePresentationBinding)
    manifest.presentation_resource.move_bindings = bindings
    var states: Array[StatePresentationBinding] = []
    for binding: StatePresentationBinding in manifest.presentation_resource.state_bindings:
        states.append(binding.duplicate(true) as StatePresentationBinding)
    manifest.presentation_resource.state_bindings = states
    return manifest

# A synthetic package whose only move is bound through Courage-style resource
# variants covering 0-1 of a 0-2 resource. With `include_fallback` the group also
# carries an unconditional binding, which is what makes the gap legal.
func _resource_variant_manifest(include_fallback: bool) -> CharacterManifest:
    var move := MoveData.new()
    move.id = &"stand_light"
    move.display_name = "stand_light"
    move.startup_frames = 1
    move.active_frames = 1
    move.recovery_frames = 1

    var move_set := MoveSetData.new()
    move_set.moves.append(move)

    var resource_data := FighterResourceData.new()
    resource_data.resource_id = &"courage"
    resource_data.min_value = 0
    resource_data.max_value = 2

    var mechanics := CharacterMechanicsData.new()
    mechanics.resources = [resource_data]

    var character := CharacterData.new()
    character.id = &"variant_probe"
    character.display_name = "Variant Probe"
    character.pushbox = BoxData.new()
    character.hurtbox = BoxData.new()
    character.move_set = move_set
    character.mechanics = mechanics

    var presentation := CharacterPresentationData.new()
    presentation.character_id = &"variant_probe"
    presentation.display_name = "Variant Probe"
    var bindings: Array[MovePresentationBinding] = []
    for value in range(0, 2):
        var binding := MovePresentationBinding.new()
        binding.move_id = &"stand_light"
        binding.animation_key = &"stand_light"
        binding.set("resource_id", &"courage")
        binding.set("resource_min_value", value)
        binding.set("resource_max_value", value)
        bindings.append(binding)
    if include_fallback:
        var fallback := MovePresentationBinding.new()
        fallback.move_id = &"stand_light"
        fallback.animation_key = &"stand_light"
        bindings.append(fallback)
    presentation.move_bindings = bindings

    var manifest := CharacterManifest.new()
    manifest.id = &"variant_probe"
    manifest.display_name = "Variant Probe"
    manifest.content_pack_id = &"variant_probe_pack"
    manifest.gameplay_resource = character
    manifest.presentation_resource = presentation
    return manifest

func _issues_with_code(index: ContentIndex, code: String) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for issue: Dictionary in index.issues():
        if issue["code"] == code:
            out.append(issue)
    return out
