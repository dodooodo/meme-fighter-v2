# Responsibility: Resource-free value snapshot for one active ProjectileRuntime.
# Static ProjectileData is represented by owner/source_move_id/spawn_index/projectile_id and rehydrated on restore.
# Owns: resource-free future-affecting value state for one active projectile.
# Does NOT own: ProjectileData Resource pointers, Nodes, presentation, static config copies.
# Dependencies: primitive Godot value types only.
class_name ProjectileSnapshot
extends RefCounted

var instance_id: int = 0
var owner_fighter_id: int = 0
var source_move_id: StringName = &""
var spawn_index: int = -1
var projectile_id: StringName = &""
var position_units: Vector2i = Vector2i.ZERO
var facing: int = 1
var remaining_lifetime_frames: int = 0
var contacted_defender_ids: Array[int] = []
var pending_despawn: bool = false
var despawn_reason: StringName = &""
