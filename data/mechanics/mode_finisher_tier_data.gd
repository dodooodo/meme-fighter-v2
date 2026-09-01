# Generic resource-value tier selecting one authored mode finisher MoveData.
class_name ModeFinisherTierData
extends Resource

@export_range(0, 100, 1) var resource_value: int = 0
@export var move_id: StringName = &""

func is_valid() -> bool:
    return resource_value > 0 and move_id != &""
