class_name CounterData
extends Resource

enum SourceMask { STRIKE = 1, PROJECTILE = 2 }

@export_range(1, 600, 1) var start_frame: int = 1
@export_range(1, 600, 1) var end_frame: int = 1
@export_flags("Strike", "Projectile") var valid_source_mask: int = SourceMask.STRIKE
@export var success_move_id: StringName = &""
