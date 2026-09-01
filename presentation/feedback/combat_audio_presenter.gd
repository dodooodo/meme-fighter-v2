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
    # The project currently ships no AudioStream assets. This stable cue hook is
    # intentionally a no-op until a real audio bank binds streams by cue.

func _cue_for_event(event: CombatEvent) -> StringName:
    if event.type in [CombatEvent.EventType.HIT, CombatEvent.EventType.BLOCK, CombatEvent.EventType.THROW, CombatEvent.EventType.KO]:
        return CombatFeedbackProfile.audio_cue_for_move(event.type, event.move_id)
    match event.type:
        CombatEvent.EventType.MOVE_STARTED:
            return &"move_started"
        CombatEvent.EventType.ROUND_STARTED:
            return &"round_start"
        CombatEvent.EventType.ROUND_ENDED:
            return &"round_end"
        CombatEvent.EventType.TIME_UP:
            return &"time_up"
        CombatEvent.EventType.MATCH_ENDED:
            return &"victory"
        _:
            return &""
