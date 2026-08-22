# Presentation-only camera midpoint follow and deterministic non-random shake.
class_name BattleCameraController
extends Node2D

var simulation: BattleSimulation
var shake_remaining_seconds: float = 0.0
var shake_strength_pixels: float = 0.0
var shake_request_count: int = 0
var _shake_elapsed: float = 0.0

func configure(p_simulation: BattleSimulation) -> void:
    simulation = p_simulation
    reset_feedback()
    sync_follow()

func _process(delta: float) -> void:
    sync_follow()
    if shake_remaining_seconds > 0.0:
        shake_remaining_seconds = maxf(0.0, shake_remaining_seconds - delta)
        _shake_elapsed += delta
        # Fixed visual pattern; no RNG and no gameplay dependency.
        var phase := int(floor(_shake_elapsed * 60.0)) % 6
        var offsets := [Vector2(1, 0), Vector2(-1, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 0), Vector2(0, 1)]
        position = _follow_position() + offsets[phase] * shake_strength_pixels
    else:
        position = _follow_position()

func sync_follow() -> void:
    if shake_remaining_seconds <= 0.0:
        position = _follow_position()

func present_event(event: CombatEvent) -> void:
    if event == null:
        return
    var strength := 0.0
    var duration := 0.10
    var tier := _impact_tier(event.move_id)
    match event.type:
        CombatEvent.EventType.BLOCK:
            strength = 1.5 + float(tier) * 0.65
            duration = 0.09
        CombatEvent.EventType.HIT:
            match tier:
                1: strength = 2.2
                2: strength = 4.5
                3: strength = 7.0
                4: strength = 10.0
            duration = 0.10 + float(tier) * 0.02
        CombatEvent.EventType.THROW:
            strength = 6.0
            duration = 0.14
        CombatEvent.EventType.KO:
            strength = 10.0
            duration = 0.20
        _:
            return
    request_shake(strength, duration)

func _impact_tier(move_id: StringName) -> int:
    if move_id == &"ultimate":
        return 4
    if move_id == &"special_neutral":
        return 3
    if move_id in [&"stand_heavy", &"ground_throw"]:
        return 2
    return 1

func request_shake(strength_pixels: float, duration_seconds: float) -> void:
    shake_strength_pixels = maxf(shake_strength_pixels, strength_pixels)
    shake_remaining_seconds = maxf(shake_remaining_seconds, duration_seconds)
    _shake_elapsed = 0.0
    shake_request_count += 1

func reset_feedback() -> void:
    shake_remaining_seconds = 0.0
    shake_strength_pixels = 0.0
    _shake_elapsed = 0.0
    position = _follow_position()

func feedback_state() -> String:
    return "SHAKE %.2f/%.1f" % [shake_remaining_seconds, shake_strength_pixels] if shake_remaining_seconds > 0.0 else "FOLLOW"

func _follow_position() -> Vector2:
    if simulation == null or simulation.fighter_a == null or simulation.fighter_b == null:
        return Vector2.ZERO
    var a := SimulationRenderConverter.to_pixels(simulation.fighter_a.movement_motor.sim_position)
    var b := SimulationRenderConverter.to_pixels(simulation.fighter_b.movement_motor.sim_position)
    return (a + b) * 0.5
