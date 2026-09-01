# Immutable custom fighter resource slot configuration.
class_name FighterResourceData
extends Resource

@export var resource_id: StringName = &""
@export var min_value: int = 0
@export var max_value: int = 1
@export var round_start_value: int = 0
@export var display_to_hud: bool = false
@export var reset_on_round: bool = true

@export_group("Conditional Movement Modifier")
# Disabled when < 0. Generic thresholded modifier used by level/resource fighters.
@export var movement_modifier_min_value: int = -1
@export_range(1, 2000, 1) var forward_walk_permille: int = 1000
# -1 keeps CharacterData recovery. Non-negative values author an exact deterministic override.
@export_range(-1, 60, 1) var dash_recovery_override_frames: int = -1
