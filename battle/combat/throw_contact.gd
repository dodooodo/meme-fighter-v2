# Responsibility: Geometry-only fact that an active throw range overlaps an eligible target.
# Owns: attacker/defender/move/AttackInstance IDs and overlap position.
# Does NOT own: HP, state mutation, guard classification, MoveData pointers, presentation.
class_name ThrowContact
extends RefCounted

var attacker_id: int = 0
var defender_id: int = 0
var move_id: StringName = &""
var attack_instance_id: int = 0
var hit_position: Vector2 = Vector2.ZERO
