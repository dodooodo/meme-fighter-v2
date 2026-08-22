# Responsibility: Complete primitive/value gameplay snapshot for one configured Fighter runtime graph.
# Does NOT contain MoveData/CharacterData/BoxData resources, Nodes, Callables, signals, or presentation state.
class_name FighterStateSnapshot
extends RefCounted

var fighter_id: int = 0
# Immutable compatibility identity. This is configuration identity, not mutable combat state.
var character_id: StringName = &""

# MovementMotor
var sim_position: Vector2i = Vector2i.ZERO
var velocity_units: Vector2i = Vector2i.ZERO
var facing: int = 1
var landed_this_frame: bool = false

# Combatant
var hp: int = 0
var hitstun_remaining: int = 0
var blockstun_remaining: int = 0
var hitstop_remaining: int = 0
var knockback_velocity_x_units: int = 0
var knockback_velocity_y_units: int = 0
var is_ko: bool = false
var last_result_type: int = -1

# MeterComponent
var meter_value: int = 0

# FighterStateMachine
var root_state: int = 0
var state: int = 0
var previous_state: int = 0
var guard_posture: int = 0
var air_attack_available: bool = true
var landing_remaining: int = 0
var dash_move_remaining: int = 0
var dash_recovery_remaining: int = 0
var thrown_remaining: int = 0
var knockdown_remaining: int = 0
var getup_remaining: int = 0
var pending_knockdown_frames: int = 0
var pending_getup_frames: int = 18
var jump_started_this_tick: bool = false
var charge_frames: int = 0
var charge_entry_move_id: StringName = &""
var charge_locked_facing: int = 1

# MoveRunner: static MoveData is represented only by stable current_move_id.
var current_move_id: StringName = &""
var move_frame: int = 0
var attack_instance_id: int = 0
var next_attack_instance_serial: int = 0
var move_connected_hit: bool = false
var move_connected_block: bool = false
var move_spawned_projectile_indices: Array[int] = []

# HitboxOwner duplicate-contact registry.
var tracked_attack_instance_id: int = -1
var contacted_defender_ids: Array[int] = []

# InputBuffer
var buffered_intent: ActionIntentSnapshot = null
var input_buffer_expiry_frame: int = -1

# InputHistory exact circular storage/cursor.
var input_history_capacity: int = 60
var input_history_write_index: int = 0
var input_history_count: int = 0
var input_history_slots: Array[InputFrameSnapshot] = []

# M10 roster mechanics (primitive + stable IDs only).
var resource_values: Dictionary = {}
var status_states: Array[Dictionary] = []
var next_status_application_serial: int = 1
var mode_state: Dictionary = {}
var mechanics_state: Dictionary = {}
var contacted_hit_keys: Array[int] = []
