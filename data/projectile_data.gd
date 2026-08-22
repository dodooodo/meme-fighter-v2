# Responsibility: Immutable deterministic combat payload/configuration for one straight-line projectile type.
# Owns: stable projectile ID, integer velocity/lifetime, static gameplay box, damage/stun/hitstop/knockback/meter data.
# Does NOT own: runtime position, owner, instance identity, contact history, Nodes, presentation, timers.
# Dependencies: MoveData hit-level semantic only.
class_name ProjectileData
extends Resource

@export_group("Identity")
@export var id: StringName = &""

@export_group("Deterministic Motion")
@export var velocity_x_units_per_tick: int = 0
@export_range(1, 3600, 1) var lifetime_frames: int = 1

@export_group("Gameplay Box")
@export var hitbox_offset: Vector2 = Vector2.ZERO
@export var hitbox_size: Vector2 = Vector2(64.0, 40.0)

@export_group("Combat")
@export_range(0, 10000, 1) var damage: int = 0
@export_range(0, 10000, 1) var chip_damage: int = 0
@export_range(0, 600, 1) var hitstun_frames: int = 0
@export_range(0, 600, 1) var blockstun_frames: int = 0
@export_range(0, 60, 1) var hitstop_attacker: int = 0
@export_range(0, 60, 1) var hitstop_defender: int = 0
@export_enum("HIGH", "MID", "LOW") var hit_level: int = MoveData.HitLevel.MID
@export var knockback_x_units: int = 0
@export var knockback_y_units: int = 0
@export_range(0, 1000, 1) var meter_gain_on_hit: int = 0
@export_range(0, 1000, 1) var meter_gain_on_block: int = 0


@export_group("Generic Mechanics")
@export var reaction_type: int = CombatReaction.Type.NONE
@export var defender_block_pushback_units: int = 0
@export var attacker_block_recoil_units: int = 0
@export var on_hit_effects: Array[GameplayEffectData] = []
@export var on_block_effects: Array[GameplayEffectData] = []

func is_valid() -> bool:
    return (
        id != &""
        and lifetime_frames > 0
        and hitbox_size.x > 0.0
        and hitbox_size.y > 0.0
        and damage >= 0
        and chip_damage >= 0
        and hitstun_frames >= 0
        and blockstun_frames >= 0
        and hitstop_attacker >= 0
        and hitstop_defender >= 0
        and meter_gain_on_hit >= 0
        and meter_gain_on_block >= 0
    )
