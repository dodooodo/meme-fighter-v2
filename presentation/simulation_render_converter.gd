# Single one-way conversion between integer simulation units and render pixels.
class_name SimulationRenderConverter
extends RefCounted

const SIMULATION_UNITS_PER_PIXEL: float = 100.0

static func to_pixels(position_units: Vector2i) -> Vector2:
    return Vector2(position_units.x, position_units.y) / SIMULATION_UNITS_PER_PIXEL

static func scalar_to_pixels(units: int) -> float:
    return float(units) / SIMULATION_UNITS_PER_PIXEL
