# Responsibility: Primitive resolved combat outcome transported from resolution to authoritative apply.
# Owns: result type, source identity, damage/stun/push/reaction/effect payload facts.
# Does NOT own: Fighter pointers, Resource mutation, collision queries, presentation state.
# Dependencies: stable IDs, CombatReaction and generic effect descriptors.

class_name HitResult
extends RefCounted

enum ResultType { HIT, BLOCK, THROW, ARMOR, COUNTERED, INVINCIBLE, WHIFF }
enum AttackSourceKind { FIGHTER_BODY, PROJECTILE, TEMPORARY_ENTITY }

var attacker_id: int = 0
var defender_id: int = 0
var move_id: StringName = &""
var attack_instance_id: int = 0
var hit_id: int = 0
var attack_source_kind: AttackSourceKind = AttackSourceKind.FIGHTER_BODY
var source_runtime_id: int = 0
var projectile_id: StringName = &""
var result_type: ResultType = ResultType.HIT
var damage: int = 0
var raw_damage: int = 0
var damage_scale_percent: int = 100
var repeated_light_scaling: bool = false
var ultimate_proration: bool = false
var chip_damage: int = 0
var hitstun_frames: int = 0
var blockstun_frames: int = 0
var hitstop_attacker: int = 0
var hitstop_defender: int = 0
var knockback_x_units: int = 0
var knockback_y_units: int = 0
var hit_position: Vector2 = Vector2.ZERO
var hit_level: int = MoveData.HitLevel.MID
var incoming_direction_x: int = 1
var counter_hit: bool = false
var defender_airborne: bool = false
var defender_move_phase: StringName = &"NONE"
var distance_units: int = 0
var attacker_cornered: bool = false
var defender_cornered: bool = false
var causes_knockdown: bool = false
var reaction_type: int = CombatReaction.Type.NONE
var throw_hold_frames: int = 0
var knockdown_frames: int = 0
var getup_frames: int = 0
var meter_gain_on_hit: int = 0
var meter_gain_on_block: int = 0
var meter_gain_on_throw: int = 0
var defender_block_pushback_units: int = 0
var attacker_block_recoil_units: int = 0
var contact_flags: int = 0
var counter_success_move_id: StringName = &""
var on_hit_effects: Array[GameplayEffectData] = []
var on_block_effects: Array[GameplayEffectData] = []
