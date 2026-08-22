class_name HazardData
extends Resource

@export var id: StringName = &""
@export_range(1, 36000, 1) var lifetime_frames: int = 60
@export_range(0, 600, 1) var telegraph_frames: int = 20
@export var half_extents_units: Vector2i = Vector2i(5000, 6000)
@export_range(0, 10000, 1) var damage: int = 60
@export_range(0, 600, 1) var hitstun_frames: int = 14
@export var knockback_x_units: int = 700
@export var reaction_type: int = 0
@export var safe_region_half_width_units: int = 0
