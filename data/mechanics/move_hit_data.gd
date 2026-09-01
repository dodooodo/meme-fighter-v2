# One independently contactable hit in a multi-hit move.
class_name MoveHitData
extends Resource

@export var hit_id: int = 0
@export_range(1, 600, 1) var active_start_frame: int = 1
@export_range(1, 600, 1) var active_end_frame: int = 1
@export var hitbox: BoxData
@export_enum("HIGH", "MID", "LOW") var hit_level: int = MoveData.HitLevel.MID
@export_range(0, 10000, 1) var damage: int = 0
@export_range(0, 10000, 1) var chip_damage: int = 0
@export_range(0, 600, 1) var hitstun_frames: int = 0
@export_range(0, 600, 1) var blockstun_frames: int = 0
@export_range(0, 60, 1) var hitstop_attacker: int = 0
@export_range(0, 60, 1) var hitstop_defender: int = 0
@export var knockback_x_units: int = 0
@export var knockback_y_units: int = 0
# -1 means inherit the owning MoveData meter reward.
@export_range(-1, 1000, 1) var meter_gain_on_hit: int = -1
@export_range(-1, 1000, 1) var meter_gain_on_block: int = -1
@export var reaction_type: int = 0
@export_range(0, 600, 1) var knockdown_frames: int = 0
@export_range(0, 600, 1) var getup_frames: int = 0
@export var counter_hit_reaction_type: int = 0
@export var counter_hit_extra_hitstun: int = 0
@export var counter_hit_extra_knockback_x_units: int = 0
@export var defender_block_pushback_units: int = 0
@export var attacker_block_recoil_units: int = 0
@export var clash_priority: int = 0
@export var conditions: Array[GameplayConditionData] = []
@export var on_hit_effects: Array[GameplayEffectData] = []
@export var on_block_effects: Array[GameplayEffectData] = []

func is_active(frame: int) -> bool:
    return frame >= active_start_frame and frame <= active_end_frame and hitbox != null
