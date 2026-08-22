# Presentation-only move ID -> animation key binding.
class_name MovePresentationBinding
extends Resource

@export var move_id: StringName = &""
@export var animation_key: StringName = &"attack"
@export var restart_on_move_start: bool = true

func is_valid() -> bool:
    return move_id != &"" and animation_key != &""
