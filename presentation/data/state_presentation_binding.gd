# Presentation-only authoritative fighter state -> animation key binding.
class_name StatePresentationBinding
extends Resource

@export var state_key: StringName = &""
@export var animation_key: StringName = &"idle"
@export var resource_id: StringName = &""
@export var resource_min_value: int = 0
@export var resource_max_value: int = 0

func is_valid() -> bool:
    return state_key != &"" and animation_key != &"" and resource_min_value <= resource_max_value

func has_resource_condition() -> bool:
    return resource_id != &""

func matches_resources(resources: FighterResourceComponent) -> bool:
    if not has_resource_condition():
        return true
    if resources == null or not resources.has(resource_id):
        return false
    var value := resources.get_value(resource_id)
    return value >= resource_min_value and value <= resource_max_value
