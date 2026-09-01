# Presentation-only exact production asset binding for one authored action/animation.
# Frame paths are inventory-backed presentation assets and never define gameplay timing/collision.
class_name ProductionAnimationBinding
extends Resource

enum Domain {
    BASE_FIGHTER,
    MODE_FIGHTER,
    PROJECTILE,
    SUMMON,
    HAZARD,
    WORLD_EFFECT,
    ATTACHMENT,
    ULTIMATE_SCREEN,
}

enum HoldPolicy {
    HOLD_LAST,
    LOOP,
    MOVE_TIMELINE,
    ONE_SHOT,
}

@export var animation_id: StringName = &""
@export var domain: Domain = Domain.BASE_FIGHTER
@export var asset_folder: String = ""
@export var round_name: StringName = &""
@export var action_folder: String = ""
@export var frame_paths: PackedStringArray = []
@export var mode_id: StringName = &""
@export var move_id: StringName = &""
@export var entity_id: StringName = &""
@export var trigger_event: StringName = &""
@export var hold_policy: HoldPolicy = HoldPolicy.HOLD_LAST
@export var loop: bool = false
@export var anchor: StringName = &"FEET_CENTER"
@export var facing_policy: StringName = &"CANONICAL_RIGHT_MIRROR"
@export var status: StringName = &"GREEN"
@export var notes: String = ""

func is_valid() -> bool:
    if animation_id == &"" or asset_folder.is_empty() or round_name == &"" or action_folder.is_empty() or frame_paths.is_empty():
        return false
    if anchor != &"FEET_CENTER" and domain in [Domain.BASE_FIGHTER, Domain.MODE_FIGHTER]:
        return false
    for path in frame_paths:
        if path.is_empty():
            return false
    return true

func is_fighter_domain() -> bool:
    return domain in [Domain.BASE_FIGHTER, Domain.MODE_FIGHTER]
