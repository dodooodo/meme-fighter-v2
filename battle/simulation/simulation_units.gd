# Responsibility: Shared deterministic-friendly integer unit conversions.
# Owns: simulation-units-per-pixel conversion.
# Does NOT own: movement or clock state.
# Dependencies: none.
class_name SimulationUnits
extends RefCounted

const UNITS_PER_PIXEL: int = 100

static func pixels_to_units(value: float) -> int:
    return int(round(value * float(UNITS_PER_PIXEL)))

static func units_to_pixels(value: int) -> float:
    return float(value) / float(UNITS_PER_PIXEL)

static func vector_units_to_pixels(value: Vector2i) -> Vector2:
    return Vector2(units_to_pixels(value.x), units_to_pixels(value.y))
