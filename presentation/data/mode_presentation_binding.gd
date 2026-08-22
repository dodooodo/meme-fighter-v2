# Presentation-only authoritative mode-id -> alternate fighter visual binding.
class_name ModePresentationBinding
extends Resource

@export var mode_id: StringName = &""
@export var fighter_visual_scene: PackedScene
@export var visual_scale: float = 1.0
@export var visual_offset_pixels: Vector2 = Vector2.ZERO
@export_file("*.json") var pack_manifest_path: String = ""
@export var enter_animation: StringName = &"idle"
@export var required_animations: Array[StringName] = []

func is_valid() -> bool:
    return mode_id != &"" and visual_scale > 0.0
