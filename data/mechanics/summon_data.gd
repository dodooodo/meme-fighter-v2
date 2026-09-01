class_name SummonData
extends Resource

@export var id: StringName = &""
# Non-empty values replace live same-owner summons with the same group before
# spawning. Empty preserves the authored multi-summon behavior.
@export var replace_group: StringName = &""
@export_range(1, 32, 1) var spawn_count: int = 1
@export_range(1, 10000, 1) var max_hp: int = 100
@export_range(1, 36000, 1) var lifetime_frames: int = 600
@export var spawn_offset_units: Vector2i = Vector2i.ZERO
@export var move_speed_units_per_tick: int = 250
@export var attack_range_units: int = 9000
@export_range(0, 600, 1) var attack_startup_frames: int = 12
@export_range(1, 600, 1) var attack_active_frames: int = 2
@export_range(0, 600, 1) var attack_recovery_frames: int = 30
@export_range(0, 10000, 1) var damage: int = 30
@export_range(0, 600, 1) var hitstun_frames: int = 8
@export var knockback_x_units: int = 500
@export var hitbox_half_extents_units: Vector2i = Vector2i(2800, 2800)
@export var hurtbox_half_extents_units: Vector2i = Vector2i(2600, 3000)

@export_group("Anti-Infinite / Interaction")
# Stable grouping key for shared target lockouts. Empty falls back to id.
@export var shared_group_id: StringName = &""
@export_range(0, 600, 1) var same_target_rehit_lockout_frames: int = 0
@export_range(0, 600, 1) var shared_group_target_lockout_frames: int = 0
# 0 = unlimited. Count resets when the owner's combo runtime resets.
@export_range(0, 32, 1) var max_hits_per_owner_combo: int = 0
# If target is already in hit/blockstun, cap this summon hit's additional hitstun. 0 = no cap.
@export_range(0, 600, 1) var owner_hitstun_target_hitstun_cap: int = 0
@export var can_cross_target: bool = true
@export var reaction_type: int = CombatReaction.Type.NONE

@export_group("Wave Scheduling")
# 0 keeps simultaneous activation; a positive size delays later groups by the authored interval.
@export_range(0, 32, 1) var spawn_wave_size: int = 0
@export_range(0, 36000, 1) var spawn_wave_interval_frames: int = 0
