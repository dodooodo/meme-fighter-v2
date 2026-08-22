class_name GoldenPairPackageTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const PACKAGE_ROOT := "res://content/characters/"
const GOLDEN_PAIR: Array[StringName] = [&"magic_orange_cat", &"salad_cat"]

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_package_manifests_register_and_preserve_roster_compatibility()
    print("\nGolden Pair package tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_package_manifests_register_and_preserve_roster_compatibility() -> void:
    var catalog := CharacterCatalog.new()
    var manifests: Array[CharacterManifest] = []
    for character_id: StringName in GOLDEN_PAIR:
        var path := PACKAGE_ROOT + String(character_id) + "/character_manifest.tres"
        t.that(ResourceLoader.exists(path), "Package manifest exists for %s" % String(character_id))
        if not ResourceLoader.exists(path):
            continue
        var manifest := load(path) as CharacterManifest
        t.that(manifest != null and manifest.is_valid(), "Package manifest validates for %s" % String(character_id))
        if manifest == null:
            continue
        manifests.append(manifest)
        t.equal(manifest.id, character_id, "Package manifest keeps stable character identity")
        t.equal(RosterRegistry.character_by_id(character_id), manifest.gameplay_resource, "Roster compatibility returns package gameplay")
        t.equal(RosterRegistry.presentation_by_id(character_id), manifest.presentation_resource, "Roster compatibility returns package presentation")
    t.equal(manifests.size(), GOLDEN_PAIR.size(), "Exactly the Golden Pair package manifests load")
    if manifests.size() == GOLDEN_PAIR.size():
        t.that(catalog.register_pack(manifests), "Golden Pair manifests register atomically")
        for character_id: StringName in GOLDEN_PAIR:
            t.equal(catalog.load_gameplay(character_id), RosterRegistry.character_by_id(character_id), "Catalog resolves package gameplay")
            t.equal(catalog.load_presentation(character_id), RosterRegistry.presentation_by_id(character_id), "Catalog resolves package presentation")
