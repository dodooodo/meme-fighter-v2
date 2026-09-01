class_name AreaData
extends Resource

@export var id: StringName = &""
@export var replace_group: StringName = &""
@export_range(1, 36000, 1) var lifetime_frames: int = 60
@export_range(0, 600, 1) var telegraph_frames: int = 0
@export_range(0, 600, 1) var arm_frames: int = 0
@export var offset_units: Vector2i = Vector2i.ZERO
@export var half_extents_units: Vector2i = Vector2i(8000, 4000)
@export var trigger_on_enemy_enter: bool = false
@export var trigger_damage: int = 0
@export var trigger_hitstun_frames: int = 0
@export var trigger_knockback_x_units: int = 0
@export var trigger_reaction_type: int = 0
@export var while_inside_status: StatusEffectData
