# Responsibility: Immutable descriptor for spawning one ProjectileData from one MoveData frame.
# Owns: 1-based move spawn frame, integer local spawn offset, ProjectileData reference.
# Does NOT own: runtime projectile identity/state, combat resolution, animation callbacks.
# Dependencies: ProjectileData only.
class_name ProjectileSpawnData
extends Resource

@export_range(1, 600, 1) var spawn_frame: int = 1
@export var spawn_offset_units: Vector2i = Vector2i.ZERO
@export var projectile_data: ProjectileData

func is_valid_for_move(total_move_frames: int) -> bool:
    return (
        spawn_frame >= 1
        and spawn_frame <= total_move_frames
        and projectile_data != null
        and projectile_data.is_valid()
    )
