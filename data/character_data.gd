# Responsibility: Shared data configuration for a fighter archetype.
# Owns: stable character identity, base stats, deterministic movement values, base gameplay boxes, MoveSetData reference.
# Does NOT own: runtime HP/state/input/presentation instances or fixed per-slot move fields.
# Dependencies: BoxData, MoveSetData.
class_name CharacterData
extends Resource

@export_group("Identity")
# Canonical immutable character identity. Do not create parallel fighter_id/character_key resource fields.
@export var id: StringName = &"generic"
@export var display_name: String = "Generic Fighter"

@export_group("Base Stats")
@export_range(1, 100000, 1) var max_hp: int = 5000
@export_range(0, 1000, 1) var max_meter: int = 100

@export_group("Ground Movement (integer simulation units per tick)")
@export var walk_forward_units_per_tick: int = 300
@export var walk_back_units_per_tick: int = 240

@export_group("Air Movement (integer simulation units per tick)")
@export var jump_velocity_y_units_per_tick: int = -1400
@export var gravity_y_units_per_tick2: int = 80
@export var max_fall_speed_y_units_per_tick: int = 1800
@export var air_forward_units_per_tick: int = 240
@export var air_back_units_per_tick: int = 210
@export_range(0, 60, 1) var landing_recovery_frames: int = 3

@export_group("Dash / Backstep (simulation frames / integer units)")
@export_range(1, 60, 1) var dash_move_frames: int = 8
@export var dash_speed_units_per_tick: int = 900
@export_range(0, 60, 1) var dash_recovery_frames: int = 4
@export_range(1, 60, 1) var backstep_move_frames: int = 7
@export var backstep_speed_units_per_tick: int = 800
@export_range(0, 60, 1) var backstep_recovery_frames: int = 6

@export_group("Forced Reaction")
@export_range(1, 600, 1) var default_getup_frames: int = 18

@export_group("Base Boxes")
@export var pushbox: BoxData
@export var hurtbox: BoxData

@export_group("Move Set")
@export var move_set: MoveSetData

@export_group("Optional Roster Mechanics")
@export var mechanics: CharacterMechanicsData
