# Responsibility: Development-only simulation clock pause and exact frame-advance control.
# Owns: paused flag and queued exact simulation-frame advances.
# Does NOT own: fighter state, HP, collision, MoveData, render pause.
class_name FrameStepper
extends RefCounted

var paused: bool = false
var _queued_steps: int = 0

func reset() -> void:
    paused = false
    _queued_steps = 0

func toggle_pause(clock: SimulationClock = null) -> void:
    paused = not paused
    _queued_steps = 0
    if clock != null:
        clock.reset()

func request_advance(frame_count: int, clock: SimulationClock = null) -> void:
    paused = true
    _queued_steps += maxi(0, frame_count)
    if clock != null:
        clock.reset()

func consume_ticks(clock: SimulationClock, render_delta: float) -> int:
    if paused:
        var result := _queued_steps
        _queued_steps = 0
        return result
    _queued_steps = 0
    return clock.consume_render_delta(render_delta)
