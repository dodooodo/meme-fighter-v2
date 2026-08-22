class_name CharacterCatalogTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func _manifest(id: StringName, pack_id: StringName) -> CharacterManifest:
	var gameplay := CharacterData.new()
	gameplay.id = id
	gameplay.display_name = String(id)
	var presentation := CharacterPresentationData.new()
	presentation.character_id = id
	presentation.display_name = String(id)
	var manifest := CharacterManifest.new()
	manifest.id = id
	manifest.display_name = String(id)
	manifest.content_pack_id = pack_id
	manifest.gameplay_resource = gameplay
	manifest.presentation_resource = presentation
	return manifest

func run_all() -> int:
	var catalog := CharacterCatalog.new()
	var alpha := _manifest(&"catalog_alpha", &"pack_alpha")
	t.that(catalog.register_pack([alpha]), "Catalog registers a valid manifest pack")
	t.equal(catalog.list_manifests().size(), 1, "Catalog lists registered manifests")
	t.equal(catalog.get_manifest(alpha.id), alpha, "Catalog resolves manifest by stable id")
	t.equal(catalog.load_gameplay(alpha.id), alpha.gameplay_resource, "Catalog loads gameplay resource")
	t.equal(catalog.load_presentation(alpha.id), alpha.presentation_resource, "Catalog loads presentation resource")
	t.that(catalog.get_manifest(&"unknown") == null, "Unknown manifest id returns null")
	t.that(not catalog.register_pack([_manifest(&"catalog_alpha", &"pack_beta")]), "Catalog rejects duplicate manifest id")
	t.that(not catalog.register_pack([_manifest(&"catalog_beta", &"pack_alpha")]), "Catalog rejects duplicate pack id")
	print("\nCharacterCatalog tests: %d passed, %d failed" % [t.passed, t.failed])
	return t.failed
