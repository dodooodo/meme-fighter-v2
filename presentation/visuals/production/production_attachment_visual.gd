# Presentation-only socket attachment visual; never contributes collision geometry.
class_name ProductionAttachmentVisual
extends Node2D

@export var texture: Texture2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    if sprite != null:
        sprite.texture = texture

func configure(binding: AttachmentPresentationBinding, facing: int = 1) -> void:
    if binding == null:
        return
    position = binding.offset_pixels
    rotation_degrees = binding.rotation_degrees
    var mirror := -1.0 if binding.mirror_with_facing and facing < 0 else 1.0
    scale = Vector2(binding.visual_scale * mirror, binding.visual_scale)
    z_index = binding.z_index_offset
    if binding.texture != null and sprite != null:
        sprite.texture = binding.texture
