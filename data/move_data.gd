# Responsibility: Data-driven frame, strike, and prototype throw properties for one move.
# Owns: startup/active/recovery, damage/stun/hitstop/knockback, static boxes, cancel windows, optional projectile spawn descriptors.
# Does NOT own: runtime move/projectile state, HP, input, animation callbacks, collision callbacks, throw target mutation.
# Dependencies: BoxData, CancelWindowData, ProjectileSpawnData, ChargeSpecialData.
class_name MoveData
extends Resource

enum HitLevel {
    HIGH,
    MID,
    LOW,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var tags: Array[StringName] = []
@export var animation_id: StringName = &""

@export_group("Frame Data")
@export_range(0, 600, 1) var startup_frames: int = 0
@export_range(0, 600, 1) var active_frames: int = 0
@export_range(0, 600, 1) var recovery_frames: int = 0

@export_group("Hit Data")
@export_range(0, 10000, 1) var damage: int = 0
@export_range(0, 10000, 1) var chip_damage: int = 0
@export_range(0, 600, 1) var hitstun_frames: int = 0
@export_range(0, 600, 1) var blockstun_frames: int = 0
@export_range(0, 60, 1) var hitstop_attacker: int = 0
@export_range(0, 60, 1) var hitstop_defender: int = 0
@export_enum("HIGH", "MID", "LOW") var hit_level: int = HitLevel.MID
@export var knockback_x_units: int = 0
@export var knockback_y_units: int = 0
@export var causes_knockdown: bool = false

@export_group("Prototype Throw")
@export var throw_box: BoxData
@export_range(0, 120, 1) var throw_hold_frames: int = 0
@export_range(0, 600, 1) var knockdown_frames: int = 0

@export_group("Meter / Future")
@export_range(0, 1000, 1) var meter_cost: int = 0
@export_range(0, 1000, 1) var meter_gain_on_hit: int = 0
@export_range(0, 1000, 1) var meter_gain_on_block: int = 0
@export_range(0, 1000, 1) var meter_gain_on_throw: int = 0
@export_range(0, 1000, 1) var meter_gain_on_whiff: int = 0

@export_group("Cancel Windows")
@export var cancel_windows: Array[CancelWindowData] = []

@export_group("Optional Generic Mechanics")
@export var charge_special_data: ChargeSpecialData

@export_group("Deterministic Ground Travel")
@export var travel_x_units_per_tick: int = 0
@export_range(0, 600, 1) var travel_start_frame: int = 0
@export_range(0, 600, 1) var travel_end_frame: int = 0

@export_group("Gameplay Boxes")
@export var hitbox: BoxData

@export_group("Deterministic Projectile Spawns")
@export var projectile_spawns: Array[ProjectileSpawnData] = []


@export_group("Multi-Hit / Reactions")
@export var hits: Array[MoveHitData] = []
@export var reaction_type: int = CombatReaction.Type.NONE
@export var counter_hit_reaction_type: int = CombatReaction.Type.NONE
@export var counter_hit_extra_hitstun_frames: int = 0
@export var counter_hit_extra_knockback_x_units: int = 0
@export var defender_block_pushback_units: int = 0
@export var attacker_block_recoil_units: int = 0
@export var clash_priority: int = 0
@export var hurtbox_overrides: Array[HurtboxOverrideData] = []
@export var armor_data: ArmorData
@export var counter_data: CounterData
@export var on_start_effects: Array[GameplayEffectData] = []
@export var on_complete_effects: Array[GameplayEffectData] = []
@export var on_hit_effects: Array[GameplayEffectData] = []
@export var on_block_effects: Array[GameplayEffectData] = []

@export_group("Generic Throw / Capture")
enum ThrowKind { NORMAL_THROW, COMMAND_GRAB, GROUND_CAPTURE_SUPER }
@export var throw_kind: ThrowKind = ThrowKind.NORMAL_THROW
@export var throw_conditions: Array[GameplayConditionData] = []
@export var throw_positioning: PositioningEffectData
@export var throw_whiff_recovery_frames: int = 0
@export var throw_avoids_backstep: bool = false

@export_group("Resource / Mode Costs")
@export var resource_cost_id: StringName = &""
@export var resource_cost_amount: int = 0

@export_group("Presentation IDs")
@export var sfx_ids: Array[StringName] = []
@export var vfx_ids: Array[StringName] = []
@export var camera_event_ids: Array[StringName] = []


func hit_payloads_for_frame(frame: int) -> Array[MoveHitData]:
    var out: Array[MoveHitData] = []
    for data: MoveHitData in hits:
        if data != null and data.is_active(frame):
            out.append(data)
    return out

func payload_for_hit_id(hit_id: int):
    if hits.is_empty():
        return self if hit_id == 0 else null
    for data: MoveHitData in hits:
        if data != null and data.hit_id == hit_id:
            return data
    return null

func active_hit_ids_for_frame(frame: int) -> Array[int]:
    var ids: Array[int] = []
    if hits.is_empty():
        if is_active_frame(frame) and hitbox != null: ids.append(0)
        return ids
    for data: MoveHitData in hits:
        if data != null and data.is_active(frame): ids.append(data.hit_id)
    ids.sort()
    return ids

func hurtbox_override_for_frame(frame: int) -> HurtboxOverrideData:
    for data: HurtboxOverrideData in hurtbox_overrides:
        if data != null and frame >= data.start_frame and frame <= data.end_frame:
            return data
    return null

func total_frames() -> int:
    return startup_frames + active_frames + recovery_frames

func first_active_frame() -> int:
    return startup_frames + 1

func last_active_frame() -> int:
    return startup_frames + active_frames

func is_active_frame(frame: int) -> bool:
    return frame >= first_active_frame() and frame <= last_active_frame()

func phase_for_frame(frame: int) -> StringName:
    if frame <= 0:
        return &"NONE"
    if frame <= startup_frames:
        return &"STARTUP"
    if frame <= startup_frames + active_frames:
        return &"ACTIVE"
    if frame <= total_frames():
        return &"RECOVERY"
    return &"COMPLETE"

func travel_x_for_frame(frame: int) -> int:
    if travel_x_units_per_tick == 0 or travel_start_frame <= 0 or travel_end_frame < travel_start_frame:
        return 0
    return travel_x_units_per_tick if frame >= travel_start_frame and frame <= travel_end_frame else 0
