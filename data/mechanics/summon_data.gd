class_name SummonData
extends Resource

@export var id: StringName = &""
@export_range(1, 32, 1) var spawn_count: int = 1
@export_range(1, 10000, 1) var max_hp: int = 100
@export_range(1, 36000, 1) var lifetime_frames: int = 600
@export var spawn_offset_units: Vector2i = Vector2i.ZERO
@export var move_speed_units_per_tick: int = 250
@export var attack_range_units: int = 9000
@export_range(0, 600, 1) var attack_startup_frames: int = 12
@export_range(1, 600, 1) var attack_active_frames: int = 2
@export_range(0, 600, 1) var attack_recovery_frames: int = 30
@export_range(0, 10000, 1) var damage: int = 30
@export_range(0, 600, 1) var hitstun_frames: int = 8
@export var knockback_x_units: int = 500
@export var hitbox_half_extents_units: Vector2i = Vector2i(2800, 2800)
@export var hurtbox_half_extents_units: Vector2i = Vector2i(2600, 3000)
