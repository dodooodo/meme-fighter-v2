class_name CharacterManifestTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
	_test_valid_manifest()
	_test_identity_mismatches_are_rejected()
	_test_missing_references_are_rejected()
	print("\nCharacterManifest tests: %d passed, %d failed" % [t.passed, t.failed])
	return t.failed

func _manifest() -> CharacterManifest:
	var gameplay := load("res://data/characters/generic_fighter.tres") as CharacterData
	var presentation := load("res://presentation/characters/generic_fighter_presentation.tres") as CharacterPresentationData
	var manifest := CharacterManifest.new()
	manifest.id = gameplay.id
	manifest.display_name = gameplay.display_name
	manifest.content_pack_id = &"base_roster"
	manifest.gameplay_resource = gameplay
	manifest.presentation_resource = presentation
	return manifest

func _test_valid_manifest() -> void:
	var manifest := _manifest()
	t.that(manifest.is_valid(), "Manifest accepts matching gameplay and presentation identities")
	t.equal(manifest.version, 1, "Manifest defaults to schema version 1")

func _test_identity_mismatches_are_rejected() -> void:
	var manifest := _manifest()
	manifest.id = &"wrong_id"
	t.that(not manifest.is_valid(), "Manifest rejects gameplay/presentation identity mismatch")

func _test_missing_references_are_rejected() -> void:
	var manifest := CharacterManifest.new()
	manifest.id = &"generic_fighter"
	manifest.display_name = "Generic Fighter"
	manifest.content_pack_id = &"base_roster"
	t.that(not manifest.is_valid(), "Manifest rejects missing referenced resources")
