# Package discovery boundary. It is intentionally separate from RosterRegistry
# and must never be used by deterministic combat authority.
class_name CharacterCatalog
extends RefCounted

const BUILTIN_ROOT: String = "res://content/characters"

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

func discover_builtin(root: String = BUILTIN_ROOT) -> bool:
	var directory := DirAccess.open(root)
	if directory == null:
		return false
	var manifest_paths := PackedStringArray()
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir() and not entry_name.begins_with(".") and not entry_name.begins_with("_"):
			var manifest_path := root.path_join(entry_name).path_join("character_manifest.tres")
			if not ResourceLoader.exists(manifest_path):
				directory.list_dir_end()
				return false
			manifest_paths.append(manifest_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
	manifest_paths.sort()
	var manifests: Array[CharacterManifest] = []
	for manifest_path: String in manifest_paths:
		var manifest := load(manifest_path) as CharacterManifest
		if manifest == null or not manifest.is_valid():
			return false
		manifests.append(manifest)
	return register_pack(manifests)

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
