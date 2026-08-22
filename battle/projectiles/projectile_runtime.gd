# Responsibility: Small mutable deterministic state for one active battle-owned projectile entity.
# Owns: stable runtime ID, owner/source provenance, integer position/facing/lifetime, duplicate-contact/despawn state.
# Does NOT own: static ProjectileData serialization truth, HP/meter mutation, Nodes, delta-time movement, presentation.
# Dependencies: ProjectileData and SimulationUnits value conversion only.
class_name ProjectileRuntime
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

# Execution cache only. Snapshot truth rehydrates this through owner -> MoveRegistry -> MoveData -> spawn index.
var projectile_data: ProjectileData = null

func configure(
    p_instance_id: int,
    p_owner_fighter_id: int,
    p_source_move_id: StringName,
    p_spawn_index: int,
    p_projectile_data: ProjectileData,
    p_position_units: Vector2i,
    p_facing: int
) -> void:
    instance_id = p_instance_id
    owner_fighter_id = p_owner_fighter_id
    source_move_id = p_source_move_id
    spawn_index = p_spawn_index
    projectile_data = p_projectile_data
    projectile_id = p_projectile_data.id if p_projectile_data != null else &""
    position_units = p_position_units
    facing = -1 if p_facing < 0 else 1
    remaining_lifetime_frames = p_projectile_data.lifetime_frames if p_projectile_data != null else 0
    contacted_defender_ids.clear()
    pending_despawn = false
    despawn_reason = &""

func can_contact(defender_id: int) -> bool:
    return not pending_despawn and not contacted_defender_ids.has(defender_id)

func record_contact(defender_id: int, reason: StringName) -> void:
    if not contacted_defender_ids.has(defender_id):
        contacted_defender_ids.append(defender_id)
    pending_despawn = true
    despawn_reason = reason

func gameplay_rect() -> Rect2:
    if projectile_data == null:
        return Rect2()
    var origin_pixels := SimulationUnits.vector_units_to_pixels(position_units)
    var center := origin_pixels + Vector2(projectile_data.hitbox_offset.x * float(facing), projectile_data.hitbox_offset.y)
    return Rect2(center - projectile_data.hitbox_size * 0.5, projectile_data.hitbox_size)
