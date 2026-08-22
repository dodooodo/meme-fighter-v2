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
    if event.type not in [CombatEvent.EventType.BLOCK, CombatEvent.EventType.HIT, CombatEvent.EventType.THROW, CombatEvent.EventType.KO]:
        return
    var tier := CombatFeedbackProfile.tier_for_move(event.move_id)
    request_shake(
        CombatFeedbackProfile.camera_strength_for(event.type, tier),
        CombatFeedbackProfile.camera_duration_for(event.type, tier)
    )

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
