# Responsibility: Shared deterministic-friendly integer unit conversions.
# Owns: simulation-units-per-pixel conversion.
# Does NOT own: movement or clock state.
# Dependencies: none.
class_name SimulationUnits
extends RefCounted

const UNITS_PER_PIXEL: int = 100
# Canonical Alpha design-space conversion. 1.0 design unit = 60 render pixels = 6000 integer simulation units.
# Choosing 6000 keeps two-decimal u/s movement speeds exactly representable per 60 Hz tick.
const DESIGN_UNIT_TO_SIM_UNITS: int = 6000
const DESIGN_MILLIUNIT_SCALE: int = 1000

static func pixels_to_units(value: float) -> int:
    return int(round(value * float(UNITS_PER_PIXEL)))

static func units_to_pixels(value: int) -> float:
    return float(value) / float(UNITS_PER_PIXEL)

static func vector_units_to_pixels(value: Vector2i) -> Vector2:
    return Vector2(units_to_pixels(value.x), units_to_pixels(value.y))


static func design_units_to_sim_units(value: float) -> int:
    # Authoring/tooling helper only. Runtime gameplay data remains integer simulation units.
    return int(round(value * float(DESIGN_UNIT_TO_SIM_UNITS)))

static func design_milliunits_to_sim_units(value_milliunits: int) -> int:
    # Deterministic integer conversion used by authored canonical values such as 2.15u -> 2150 milli-u.
    var scaled := value_milliunits * DESIGN_UNIT_TO_SIM_UNITS
    if scaled >= 0:
        return (scaled + DESIGN_MILLIUNIT_SCALE / 2) / DESIGN_MILLIUNIT_SCALE
    return (scaled - DESIGN_MILLIUNIT_SCALE / 2) / DESIGN_MILLIUNIT_SCALE

static func design_speed_centiu_per_second_to_units_per_tick(value_centiu_per_second: int) -> int:
    # With 6000 sim-u/design-u and 60 Hz: 0.01u/s == 1 sim-u/tick exactly.
    return value_centiu_per_second
