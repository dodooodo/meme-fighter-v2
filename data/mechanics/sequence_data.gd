class_name SequenceData
extends Resource

@export var id: StringName = &""
@export_range(1, 36000, 1) var duration_frames: int = 60
@export var interruptible_owner_hit: bool = false
@export var steps: Array[SequenceStepData] = []
