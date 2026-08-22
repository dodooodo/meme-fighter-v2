# Immutable timed status configuration. All durations are simulation frames.
class_name StatusEffectData
extends Resource

enum RefreshPolicy { KEEP_LONGER, REFRESH, REPLACE }

@export var id: StringName = &""
@export_range(1, 36000, 1) var duration_frames: int = 1
@export var refresh_policy: RefreshPolicy = RefreshPolicy.REFRESH
@export var stackable: bool = false
@export_range(1, 32, 1) var max_stacks: int = 1
@export_range(1, 2000, 1) var walk_speed_permille: int = 1000
@export_range(1, 2000, 1) var dash_speed_permille: int = 1000
@export_range(1, 2000, 1) var backstep_speed_permille: int = 1000
@export var freeze_during_hitstop: bool = true
