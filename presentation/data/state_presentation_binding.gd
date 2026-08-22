# Presentation-only authoritative fighter state -> animation key binding.
class_name StatePresentationBinding
extends Resource

@export var state_key: StringName = &""
@export var animation_key: StringName = &"idle"

func is_valid() -> bool:
    return state_key != &"" and animation_key != &""
