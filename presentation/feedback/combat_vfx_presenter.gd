# Deduped CombatEvent -> presentation-only impact VFX. Gameplay geometry is never read back from VFX.
class_name CombatVfxPresenter
extends Node2D

var spawn_count: int = 0
var flash_count: int = 0
var last_impact_intensity: float = 0.0
var last_flash_alpha: float = 0.0

func present_event(event: CombatEvent) -> void:
    if event == null:
        return
    if event.type not in [CombatEvent.EventType.HIT, CombatEvent.EventType.BLOCK, CombatEvent.EventType.THROW, CombatEvent.EventType.KO]:
        return
    var effect := PlaceholderCombatVfx.new()
    var tier := CombatFeedbackProfile.tier_for_move(event.move_id)
    last_impact_intensity = CombatFeedbackProfile.vfx_intensity_for(event.type, tier)
    last_flash_alpha = CombatFeedbackProfile.flash_alpha_for(event.type, tier)
    effect.configure(
        CombatFeedbackProfile.vfx_color_for_move(event.type, event.move_id),
        CombatFeedbackProfile.vfx_radius_for(event.type, tier),
        last_impact_intensity,
        CombatFeedbackProfile.vfx_rays_for(event.type, tier),
        CombatFeedbackProfile.vfx_lifetime_for(event.type, tier)
    )
    effect.position = event.position
    add_child(effect)
    spawn_count += 1
    if last_flash_alpha > 0.0:
        var flash := CombatWhiteFlash.new()
        add_child(flash)
        flash.configure(
            last_flash_alpha,
            CombatFeedbackProfile.flash_duration_for(event.type, tier),
            CombatFeedbackProfile.flash_color_for_move(event.type, event.move_id)
        )
        flash_count += 1

func clear_all() -> void:
    for child in get_children():
        child.queue_free()
