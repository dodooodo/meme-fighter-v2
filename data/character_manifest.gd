# Discovery metadata for one character package. This resource never enters combat state.
class_name CharacterManifest
extends Resource

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_range(1, 2147483647, 1) var version: int = 1
@export var content_pack_id: StringName = &""
@export var available: bool = true

@export_group("References")
@export var gameplay_resource: CharacterData
@export var presentation_resource: CharacterPresentationData
@export var portrait: Texture2D
@export var icon: Texture2D

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("manifest id must be non-empty")
	if display_name.strip_edges().is_empty():
		errors.append("manifest display_name must be non-empty")
	if content_pack_id == &"":
		errors.append("manifest content_pack_id must be non-empty")
	if gameplay_resource == null:
		errors.append("manifest gameplay_resource is required")
	elif gameplay_resource.id != id:
		errors.append("gameplay resource id mismatch")
	if presentation_resource == null:
		errors.append("manifest presentation_resource is required")
	elif presentation_resource.character_id != id:
		errors.append("presentation resource id mismatch")
	return errors

func is_valid() -> bool:
	return validate().is_empty()
