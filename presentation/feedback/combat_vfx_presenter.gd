# Deduped CombatEvent -> presentation-only impact VFX. Gameplay geometry is never read back from VFX.
class_name CombatVfxPresenter
extends Node2D

var spawn_count: int = 0

func present_event(event: CombatEvent) -> void:
    if event == null:
        return
    if event.type not in [CombatEvent.EventType.HIT, CombatEvent.EventType.BLOCK, CombatEvent.EventType.THROW, CombatEvent.EventType.KO]:
        return
    var effect := PlaceholderCombatVfx.new()
    var tier := _impact_tier(event.move_id)
    var color := Color(1.0, 0.35, 0.25, 0.92)
    var radius := 14.0
    var intensity := 0.8
    var rays := 4
    var lifetime := 0.16

    if event.type == CombatEvent.EventType.BLOCK:
        color = Color(0.35, 0.68, 1.0, 0.88)
        radius = 12.0 + float(tier) * 2.0
        intensity = 0.65 + float(tier) * 0.10
        rays = 3 + tier
        lifetime = 0.14
    elif event.type == CombatEvent.EventType.THROW:
        color = Color(1.0, 0.75, 0.25, 0.92)
        radius = 22.0
        intensity = 1.15
        rays = 7
        lifetime = 0.20
    elif event.type == CombatEvent.EventType.KO:
        color = Color(1.0, 0.18, 0.16, 0.96)
        radius = 38.0
        intensity = 1.65
        rays = 12
        lifetime = 0.28
    else:
        match tier:
            1: # light
                radius = 14.0
                intensity = 0.75
                rays = 4
                lifetime = 0.14
            2: # heavy
                radius = 21.0
                intensity = 1.05
                rays = 6
                lifetime = 0.18
            3: # special
                radius = 29.0
                intensity = 1.35
                rays = 9
                lifetime = 0.22
                color = Color(1.0, 0.48, 0.18, 0.95)
            4: # ultimate
                radius = 41.0
                intensity = 1.70
                rays = 12
                lifetime = 0.28
                color = Color(1.0, 0.82, 0.22, 0.98)

    effect.configure(color, radius, intensity, rays, lifetime)
    effect.position = event.position
    add_child(effect)
    spawn_count += 1

func _impact_tier(move_id: StringName) -> int:
    if move_id == &"ultimate":
        return 4
    if move_id == &"special_neutral":
        return 3
    if move_id in [&"stand_heavy", &"ground_throw"]:
        return 2
    return 1

func clear_all() -> void:
    for child in get_children():
        child.queue_free()
