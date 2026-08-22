# Presentation-only dedupe state. Never snapshot/hash.
class_name PresentationEventLedger
extends RefCounted

var _presented: Dictionary = {}
var last_presented_event_id: String = ""

func has_presented(event_id: String) -> bool:
    return _presented.has(event_id)

func should_present(event: CombatEvent) -> bool:
    return not has_presented(PresentationEventId.canonical(event))

func mark_presented(event: CombatEvent) -> void:
    var event_id := PresentationEventId.canonical(event)
    _presented[event_id] = event.frame_number
    last_presented_event_id = event_id

func consume_once(event: CombatEvent) -> bool:
    var event_id := PresentationEventId.canonical(event)
    if _presented.has(event_id):
        return false
    _presented[event_id] = event.frame_number
    last_presented_event_id = event_id
    return true

func clear() -> void:
    _presented.clear()
    last_presented_event_id = ""

func forget_after_frame(frame_number: int) -> void:
    var remove_ids: Array = []
    for event_id in _presented.keys():
        if int(_presented[event_id]) > frame_number:
            remove_ids.append(event_id)
    for event_id in remove_ids:
        _presented.erase(event_id)
    if last_presented_event_id != "" and not _presented.has(last_presented_event_id):
        last_presented_event_id = ""

func count() -> int:
    return _presented.size()
