# Data-only CPU reaction/error profile. It changes input policy only; never fighter stats.
class_name CpuDifficultyData
extends Resource

@export var id: StringName = &"normal"
@export_range(1, 120, 1) var reaction_min_frames: int = 15
@export_range(1, 120, 1) var reaction_max_frames: int = 24
@export_range(0, 100, 1) var decision_error_percent: int = 18
@export_range(1, 30, 1) var decision_interval_frames: int = 6

func is_valid() -> bool:
    return id != &"" and reaction_min_frames > 0 and reaction_max_frames >= reaction_min_frames and decision_error_percent >= 0 and decision_error_percent <= 100 and decision_interval_frames > 0
