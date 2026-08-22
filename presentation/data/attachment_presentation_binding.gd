# Presentation-only socket attachment. Gameplay collision never derives from this resource.
class_name AttachmentPresentationBinding
extends Resource

@export var attachment_id: StringName = &""
@export var visual_scene: PackedScene
@export var texture: Texture2D
@export var socket_id: EffectPresentationBinding.AnchorSocket = EffectPresentationBinding.AnchorSocket.WEAPON
@export var offset_pixels: Vector2 = Vector2.ZERO
@export var rotation_degrees: float = 0.0
@export var visual_scale: float = 1.0
@export var mirror_with_facing: bool = true
@export var z_index_offset: int = 0

func is_valid() -> bool:
    return attachment_id != &"" and visual_scale > 0.0 and (visual_scene != null or texture != null)
