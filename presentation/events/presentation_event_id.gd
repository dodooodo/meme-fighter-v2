# Deterministic presentation identity derived only from stable gameplay facts.
class_name PresentationEventId
extends RefCounted

static func canonical(event: CombatEvent) -> String:
    if event == null:
        return "INVALID"
    var event_name: String = CombatEvent.EventType.keys()[event.type]
    return "F%d:%s:A%d:D%d:M%s:AI%d:PI%d:R%d:RR%d" % [
        event.frame_number,
        event_name,
        event.attacker_id,
        event.defender_id,
        String(event.move_id),
        event.attack_instance_id,
        event.projectile_instance_id,
        event.round_number,
        event.round_result,
    ]
