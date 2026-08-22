class_name HurtboxOverrideData
extends Resource

@export_range(1, 600, 1) var start_frame: int = 1
@export_range(1, 600, 1) var end_frame: int = 1
@export var hurtbox: BoxData

func active(frame: int) -> bool:
    return frame >= start_frame and frame <= end_frame and hurtbox != null
