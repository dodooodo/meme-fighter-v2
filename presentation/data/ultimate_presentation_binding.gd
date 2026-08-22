# Presentation-only screen-space Ultimate art binding.
class_name UltimatePresentationBinding
extends Resource

@export var ultimate_id: StringName = &"ultimate"
@export var background_scene: PackedScene
@export var cutin_scene: PackedScene
@export var overlay_scene: PackedScene
@export_file("*.json") var background_manifest_path: String = ""
@export var screen_tint: Color = Color.WHITE
@export var camera_effect_profile: StringName = &"default"

func is_valid() -> bool:
    return ultimate_id != &""
