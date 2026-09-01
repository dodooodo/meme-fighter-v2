# Immutable configuration for generic hold/release charge-special selection.
class_name ChargeSpecialData
extends Resource

@export_range(1, 60, 1) var minimum_level_1_frames: int = 3
@export_range(1, 600, 1) var level_2_threshold_frames: int = 24
@export_range(1, 600, 1) var level_3_threshold_frames: int = 54
@export var level_1_move_id: StringName = &"special_neutral"
@export var level_2_move_id: StringName = &"special_neutral_l2"
@export var level_3_move_id: StringName = &"special_neutral_l3"

func is_valid() -> bool:
    return (
        minimum_level_1_frames > 0
        and level_2_threshold_frames > minimum_level_1_frames
        and level_3_threshold_frames > level_2_threshold_frames
        and level_1_move_id != &""
        and level_2_move_id != &""
        and level_3_move_id != &""
    )

func move_id_for_charge_frames(frames: int) -> StringName:
    if frames >= level_3_threshold_frames:
        return level_3_move_id
    if frames >= level_2_threshold_frames:
        return level_2_move_id
    return level_1_move_id

func level_for_charge_frames(frames: int) -> int:
    if frames < minimum_level_1_frames:
        return 0
    if frames >= level_3_threshold_frames:
        return 3
    if frames >= level_2_threshold_frames:
        return 2
    return 1
