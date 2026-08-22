# Presentation-only projectile stable ID -> visual scene binding.
class_name ProjectilePresentationBinding
extends Resource

@export var projectile_id: StringName = &""
@export var visual_scene: PackedScene
@export var placeholder_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var visual_scale: float = 1.0

func is_valid() -> bool:
    return projectile_id != &"" and visual_scale > 0.0
