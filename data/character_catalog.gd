# Package discovery boundary. It is intentionally separate from RosterRegistry
# and must never be used by deterministic combat authority.
class_name CharacterCatalog
extends RefCounted

var _manifests: Array[CharacterManifest] = []
var _by_id: Dictionary = {}
var _pack_ids: Dictionary = {}

func list_manifests() -> Array[CharacterManifest]:
	return _manifests.duplicate()

func get_manifest(id: StringName) -> CharacterManifest:
	return _by_id.get(id, null) as CharacterManifest

func load_gameplay(id: StringName) -> CharacterData:
	var manifest := get_manifest(id)
	return manifest.gameplay_resource if manifest != null else null

func load_presentation(id: StringName) -> CharacterPresentationData:
	var manifest := get_manifest(id)
	return manifest.presentation_resource if manifest != null else null

func register_pack(pack: Array[CharacterManifest]) -> bool:
	if pack.is_empty():
		return false
	var staged_ids: Dictionary = {}
	var staged_pack_ids: Dictionary = {}
	for manifest: CharacterManifest in pack:
		if manifest == null or not manifest.is_valid():
			return false
		if _by_id.has(manifest.id) or staged_ids.has(manifest.id):
			return false
		if _pack_ids.has(manifest.content_pack_id) or staged_pack_ids.has(manifest.content_pack_id):
			return false
		staged_ids[manifest.id] = true
		staged_pack_ids[manifest.content_pack_id] = true
	for manifest: CharacterManifest in pack:
		_manifests.append(manifest)
		_by_id[manifest.id] = manifest
		_pack_ids[manifest.content_pack_id] = true
	return true
