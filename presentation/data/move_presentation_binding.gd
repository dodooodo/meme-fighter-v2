# Presentation-only move ID -> animation key binding.
class_name MovePresentationBinding
extends Resource

@export var move_id: StringName = &""
@export var animation_key: StringName = &"attack"
@export var restart_on_move_start: bool = true
@export var resource_id: StringName = &""
@export var resource_min_value: int = 0
@export var resource_max_value: int = 0

func is_valid() -> bool:
    return move_id != &"" and animation_key != &"" and resource_min_value <= resource_max_value

func has_resource_condition() -> bool:
    return resource_id != &""

func matches_resources(resources: FighterResourceComponent) -> bool:
    if not has_resource_condition():
        return true
    if resources == null or not resources.has(resource_id):
        return false
    var value := resources.get_value(resource_id)
    return value >= resource_min_value and value <= resource_max_value
