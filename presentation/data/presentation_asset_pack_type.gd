# Presentation-only asset domain identity. Gameplay code must never depend on this type.
class_name PresentationAssetPackType
extends RefCounted

enum PackType {
    BASE_FIGHTER,
    MODE_FIGHTER,
    WORLD_EFFECT,
    PROJECTILE,
    HAZARD,
    ULTIMATE_SCREEN,
    ATTACHMENT,
}

const NAMES := {
    PackType.BASE_FIGHTER: &"BASE_FIGHTER",
    PackType.MODE_FIGHTER: &"MODE_FIGHTER",
    PackType.WORLD_EFFECT: &"WORLD_EFFECT",
    PackType.PROJECTILE: &"PROJECTILE",
    PackType.HAZARD: &"HAZARD",
    PackType.ULTIMATE_SCREEN: &"ULTIMATE_SCREEN",
    PackType.ATTACHMENT: &"ATTACHMENT",
}

static func name_for(pack_type: int) -> StringName:
    return NAMES.get(pack_type, &"UNKNOWN") as StringName

static func is_world_space(pack_type: int) -> bool:
    return pack_type in [PackType.WORLD_EFFECT, PackType.PROJECTILE, PackType.HAZARD, PackType.ATTACHMENT]
