# Character-specific data-only utility weights consumed by generic CpuInputSource.
class_name CpuUtilityProfile
extends Resource

@export var character_id: StringName = &""
@export var archetype: String = ""
@export var preferred_range_min_units: int = 12000
@export var preferred_range_max_units: int = 30000
@export_range(0, 200, 1) var approach_weight: int = 50
@export_range(0, 200, 1) var retreat_weight: int = 30
@export_range(0, 200, 1) var light_weight: int = 40
@export_range(0, 200, 1) var heavy_weight: int = 40
@export_range(0, 200, 1) var low_weight: int = 30
@export_range(0, 200, 1) var air_weight: int = 20
@export_range(0, 200, 1) var anti_air_weight: int = 30
@export_range(0, 200, 1) var throw_weight: int = 25
@export_range(0, 200, 1) var special_lv1_weight: int = 25
@export_range(0, 200, 1) var special_lv2_weight: int = 35
@export_range(0, 200, 1) var special_lv3_weight: int = 35
@export_range(0, 200, 1) var ultimate_weight: int = 25
@export_range(0, 200, 1) var guard_weight: int = 35
@export_range(0, 200, 1) var backstep_weight: int = 20
@export_range(0, 200, 1) var jump_weight: int = 20
@export_range(0, 200, 1) var resource_spend_weight: int = 35
@export_range(0, 200, 1) var mode_activation_weight: int = 30
@export_range(0, 200, 1) var summon_weight: int = 20
@export_range(0, 200, 1) var trap_weight: int = 20
@export_range(0, 200, 1) var counter_weight: int = 20
@export var notes: String = ""

func is_valid() -> bool:
    return character_id != &"" and preferred_range_min_units >= 0 and preferred_range_max_units >= preferred_range_min_units
