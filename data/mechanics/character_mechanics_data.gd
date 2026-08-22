# Optional immutable composition root for roster-specific generic mechanics.
class_name CharacterMechanicsData
extends Resource

@export var resources: Array[FighterResourceData] = []
@export var statuses: Array[StatusEffectData] = []
@export var modes: Array[ModeData] = []
@export var defense_modifiers: Array[DefenseModifierData] = []
@export_range(0, 120, 1) var crouch_guard_exit_window_frames: int = 0
@export var panic_exit_status_id: StringName = &""
@export_range(1, 2000, 1) var panic_backstep_speed_permille: int = 1000
@export var panic_backstep_startup_reduction_frames: int = 0
@export var last_stand_mode_id: StringName = &""
@export var last_stand_resolve_resource_id: StringName = &""
@export var heavy_knockdown_resource_id: StringName = &""
@export var heavy_knockdown_resource_loss: int = 0
@export var successful_hit_grants_status_id: StringName = &""
@export var last_stand_expiry_move_ids: Array[StringName] = []
