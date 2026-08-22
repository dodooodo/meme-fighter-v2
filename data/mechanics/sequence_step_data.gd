class_name SequenceStepData
extends Resource

@export_range(0, 36000, 1) var start_frame: int = 0
@export var kind: StringName = &"STRIKE"
@export var offset_units: Vector2i = Vector2i.ZERO
@export var half_extents_units: Vector2i = Vector2i(5000, 5000)
@export_range(0, 600, 1) var telegraph_frames: int = 0
@export_range(0, 10000, 1) var damage: int = 0
@export_range(0, 600, 1) var hitstun_frames: int = 0
@export var hit_level: int = MoveData.HitLevel.MID
@export var reaction_type: int = 0
@export var record_target_position: bool = false
@export var record_slot: int = -1
@export var use_recorded_position: bool = false
@export var require_target_status: StringName = &""
@export var exclude_target_status: StringName = &""
@export var consume_target_status: StringName = &""
@export var safe_region_half_width_units: int = 0
