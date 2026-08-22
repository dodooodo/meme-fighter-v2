# Presentation-only world effect/hazard binding. It never defines gameplay geometry.
class_name EffectPresentationBinding
extends Resource

enum TriggerEvent {
    MANUAL,
    MOVE_STARTED,
    CHARGE_LEVEL_CHANGED,
    RELEASE_STARTED,
    ACTIVE_STARTED,
    HIT,
    BLOCK,
    MOVE_ENDED,
}

enum AnchorSocket {
    FEET_CENTER,
    BODY_CENTER,
    HEAD,
    MOUTH,
    LEFT_HAND,
    RIGHT_HAND,
    WEAPON,
    CUSTOM_OFFSET,
}

@export var effect_id: StringName = &""
@export var pack_type: int = PresentationAssetPackType.PackType.WORLD_EFFECT
@export var visual_scene: PackedScene
@export_file("*.json") var pack_manifest_path: String = ""
@export var move_id: StringName = &""
@export var trigger_event: TriggerEvent = TriggerEvent.MANUAL
@export var anchor_socket: AnchorSocket = AnchorSocket.FEET_CENTER
@export var offset_pixels: Vector2 = Vector2.ZERO
@export var mirror_with_facing: bool = true
@export var z_index_offset: int = 0
@export var visual_scale: float = 1.0

func is_valid() -> bool:
    if effect_id == &"" or visual_scale <= 0.0:
        return false
    return pack_type in [
        PresentationAssetPackType.PackType.WORLD_EFFECT,
        PresentationAssetPackType.PackType.HAZARD,
    ]
