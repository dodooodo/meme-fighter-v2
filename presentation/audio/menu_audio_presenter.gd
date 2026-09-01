# Presentation-only menu cue hook. It deliberately has no fallback file path:
# audio streams can be added later without changing menu/gameplay flow.
class_name MenuAudioPresenter
extends Node

var cue_dispatch_count: int = 0
var last_cue: StringName = &""

func present_confirm() -> void:
    cue_dispatch_count += 1
    last_cue = &"menu_confirm"
