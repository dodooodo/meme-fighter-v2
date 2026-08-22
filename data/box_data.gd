# Responsibility: Immutable-ish gameplay box definition in local fighter space.
# Owns: local offset and size.
# Does NOT own: collision resolution, sprites, physics bodies, damage.
# Dependencies: Godot Resource primitives only.
class_name BoxData
extends Resource

@export var offset: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(64.0, 128.0)

func world_rect(origin_pixels: Vector2, facing: int = 1) -> Rect2:
    var center := origin_pixels + Vector2(offset.x * float(facing), offset.y)
    return Rect2(center - size * 0.5, size)

func is_valid() -> bool:
    return size.x > 0.0 and size.y > 0.0
