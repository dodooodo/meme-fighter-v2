# Responsibility: Immutable-style geometry contact facts for one strike overlap.
# Owns: fighter IDs, move/attack identity, hit position, incoming world-side direction.
# Does NOT own: HIT/BLOCK classification, HP/stun mutation, MoveData ownership, state transitions, presentation.
# Dependencies: primitive simulation values only.
class_name StrikeContact
extends RefCounted

var attacker_id: int = 0
var defender_id: int = 0
var move_id: StringName = &""
var attack_instance_id: int = 0
var hit_id: int = 0
var hit_position: Vector2 = Vector2.ZERO
var incoming_direction_x: int = 1
