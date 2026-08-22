# Audio cue hook foundation. Missing streams are intentional no-op placeholders.
class_name CombatAudioPresenter
extends Node

var cue_dispatch_count: int = 0
var last_cue: StringName = &""

func present_event(event: CombatEvent) -> void:
    if event == null:
        return
    var cue := _cue_for_event(event)
    if cue == &"":
        return
    cue_dispatch_count += 1
    last_cue = cue
    # M7 has no formal audio assets; future bindings may play AudioStreamPlayer here.

func _cue_for_event(event: CombatEvent) -> StringName:
    match event.type:
        CombatEvent.EventType.MOVE_STARTED:
            return &"move_started"
        CombatEvent.EventType.HIT:
            return &"hit"
        CombatEvent.EventType.BLOCK:
            return &"block"
        CombatEvent.EventType.THROW:
            return &"throw"
        CombatEvent.EventType.KO:
            return &"ko"
        CombatEvent.EventType.ROUND_STARTED:
            return &"round_start"
        CombatEvent.EventType.ROUND_ENDED:
            return &"round_end"
        CombatEvent.EventType.TIME_UP:
            return &"time_up"
        CombatEvent.EventType.MATCH_ENDED:
            return &"match_end"
        _:
            return &""
