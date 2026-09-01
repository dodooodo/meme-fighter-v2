# Authoritative mode configuration. Mode state lives in ModeComponent, not Presentation.
class_name ModeData
extends Resource

@export var mode_id: StringName = &""
@export_range(0, 36000, 1) var duration_frames: int = 0
@export_range(1, 2000, 1) var forward_walk_permille: int = 1000
@export_range(1, 2000, 1) var back_walk_permille: int = 1000
@export_range(1, 2000, 1) var dash_speed_permille: int = 1000
@export_range(1, 2000, 1) var backstep_speed_permille: int = 1000
@export_range(1, 2000, 1) var air_forward_permille: int = 1000
@export_range(1, 2000, 1) var air_back_permille: int = 1000
@export var guard_allowed: bool = true
@export var move_overrides: Array[ModeMoveOverrideData] = []
@export var exit_when_resource_zero_id: StringName = &""
@export_range(0, 600, 1) var exit_recovery_frames: int = 0
@export var freeze_during_hitstop: bool = true

@export var exit_move_id: StringName = &""
@export var finisher_enabled: bool = false
@export var finisher_move_id: StringName = &""
@export var finisher_resource_id: StringName = &""
@export_range(0, 100, 1) var finisher_min_resource: int = 0
@export var finisher_tiers: Array[ModeFinisherTierData] = []

func finisher_move_for_resource(value: int) -> StringName:
    for tier: ModeFinisherTierData in finisher_tiers:
        if tier != null and tier.resource_value == value:
            return tier.move_id
    return finisher_move_id
