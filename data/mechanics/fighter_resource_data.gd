# Immutable custom fighter resource slot configuration.
class_name FighterResourceData
extends Resource

@export var resource_id: StringName = &""
@export var min_value: int = 0
@export var max_value: int = 1
@export var round_start_value: int = 0
@export var display_to_hud: bool = false
@export var reset_on_round: bool = true
