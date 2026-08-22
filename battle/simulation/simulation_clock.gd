# Responsibility: Convert variable render delta into a count of fixed 60 Hz simulation ticks.
# Owns: scheduler accumulator only.
# Does NOT own: combat state, frame data, collision, input semantics.
# Dependencies: none.
class_name SimulationClock
extends RefCounted

const FIXED_HZ: int = 60
const FIXED_STEP_SECONDS: float = 1.0 / 60.0
const MAX_CATCH_UP_TICKS: int = 8
const EPSILON: float = 0.000000001

var _accumulator: float = 0.0

func reset() -> void:
    _accumulator = 0.0

func consume_render_delta(render_delta: float) -> int:
    _accumulator += maxf(0.0, render_delta)
    var ticks := 0
    while _accumulator + EPSILON >= FIXED_STEP_SECONDS and ticks < MAX_CATCH_UP_TICKS:
        _accumulator -= FIXED_STEP_SECONDS
        ticks += 1
    if ticks >= MAX_CATCH_UP_TICKS and _accumulator > FIXED_STEP_SECONDS * float(MAX_CATCH_UP_TICKS):
        _accumulator = FIXED_STEP_SECONDS * float(MAX_CATCH_UP_TICKS)
    return ticks
