# Shared presentation-only impact hierarchy. Never read by gameplay simulation.
class_name CombatFeedbackProfile
extends RefCounted

static func tier_for_move(move_id: StringName) -> int:
    if move_id == &"ultimate":
        return 4
    if move_id in [&"special_neutral", &"special_neutral_l2", &"special_neutral_l3"]:
        return 3
    if move_id in [&"stand_heavy", &"ground_throw"]:
        return 2
    return 1

static func tier_name_for_move(move_id: StringName) -> String:
    return ["", "light", "heavy", "special", "ultimate"][tier_for_move(move_id)]

static func vfx_intensity_for(event_type: int, tier: int) -> float:
    if event_type == CombatEvent.EventType.BLOCK:
        return 0.55 + 0.08 * float(tier)
    if event_type == CombatEvent.EventType.THROW:
        return 1.15
    if event_type == CombatEvent.EventType.KO:
        return 1.85
    return [0.0, 0.75, 1.05, 1.35, 1.70][clampi(tier, 1, 4)]

static func vfx_radius_for(event_type: int, tier: int) -> float:
    if event_type == CombatEvent.EventType.BLOCK:
        return 12.0 + float(tier) * 2.0
    if event_type == CombatEvent.EventType.THROW:
        return 22.0
    if event_type == CombatEvent.EventType.KO:
        return 44.0
    return [0.0, 14.0, 21.0, 29.0, 41.0][clampi(tier, 1, 4)]

static func vfx_rays_for(event_type: int, tier: int) -> int:
    if event_type == CombatEvent.EventType.BLOCK:
        return 3 + tier
    if event_type == CombatEvent.EventType.THROW:
        return 7
    if event_type == CombatEvent.EventType.KO:
        return 12
    return [0, 4, 6, 9, 12][clampi(tier, 1, 4)]

static func vfx_lifetime_for(event_type: int, tier: int) -> float:
    if event_type == CombatEvent.EventType.BLOCK:
        return 0.14
    if event_type == CombatEvent.EventType.THROW:
        return 0.20
    if event_type == CombatEvent.EventType.KO:
        return 0.32
    return [0.0, 0.14, 0.18, 0.22, 0.28][clampi(tier, 1, 4)]

static func vfx_color_for(event_type: int, tier: int) -> Color:
    if event_type == CombatEvent.EventType.BLOCK:
        return Color(0.35, 0.68, 1.0, 0.88)
    if event_type == CombatEvent.EventType.THROW:
        return Color(1.0, 0.75, 0.25, 0.92)
    if event_type == CombatEvent.EventType.KO:
        return Color(1.0, 0.18, 0.16, 0.98)
    if tier == 4:
        return Color(1.0, 0.82, 0.22, 0.98)
    if tier == 3:
        return Color(1.0, 0.48, 0.18, 0.95)
    return Color(1.0, 0.35, 0.25, 0.92)

static func camera_strength_for(event_type: int, tier: int) -> float:
    if event_type == CombatEvent.EventType.BLOCK:
        return 1.5 + float(tier) * 0.65
    if event_type == CombatEvent.EventType.THROW:
        return 6.0
    if event_type == CombatEvent.EventType.KO:
        return 12.0
    return [0.0, 2.2, 4.5, 7.0, 10.0][clampi(tier, 1, 4)]

static func camera_duration_for(event_type: int, tier: int) -> float:
    if event_type == CombatEvent.EventType.BLOCK:
        return 0.09
    if event_type == CombatEvent.EventType.THROW:
        return 0.14
    if event_type == CombatEvent.EventType.KO:
        return 0.24
    return 0.10 + float(tier) * 0.02

static func flash_alpha_for(event_type: int, tier: int) -> float:
    if event_type == CombatEvent.EventType.BLOCK:
        return [0.0, 0.025, 0.045, 0.065, 0.085][clampi(tier, 1, 4)]
    if event_type == CombatEvent.EventType.THROW:
        return 0.16
    if event_type == CombatEvent.EventType.KO:
        return 0.36
    return [0.0, 0.04, 0.10, 0.20, 0.30][clampi(tier, 1, 4)]

static func flash_duration_for(event_type: int, tier: int) -> float:
    if event_type == CombatEvent.EventType.BLOCK:
        return 0.045
    if event_type == CombatEvent.EventType.KO:
        return 0.12
    return 0.04 + 0.012 * float(tier)

static func audio_cue_for(event_type: int, tier: int) -> StringName:
    var tier_name: String = ["", "light", "heavy", "special", "ultimate"][clampi(tier, 1, 4)]
    match event_type:
        CombatEvent.EventType.HIT:
            return StringName("hit_%s" % tier_name)
        CombatEvent.EventType.BLOCK:
            return StringName("block_%s" % tier_name)
        CombatEvent.EventType.THROW:
            return &"throw_heavy"
        CombatEvent.EventType.KO:
            return &"ko_ultimate"
        _:
            return &""
