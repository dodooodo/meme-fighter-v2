# Screen-space round/match messaging. Visual duration never gates RoundController.
class_name RoundPresentationOverlay
extends Control

@onready var message_label: Label = $Message
var visual_message: String = ""
var visual_message_remaining: float = 0.0

func _process(delta: float) -> void:
    if visual_message_remaining > 0.0:
        visual_message_remaining = maxf(0.0, visual_message_remaining - delta)
        if visual_message_remaining <= 0.0 and message_label != null:
            message_label.text = ""

func present_event(event: CombatEvent) -> void:
    if event == null:
        return
    match event.type:
        CombatEvent.EventType.ROUND_STARTED:
            show_message("ROUND %d\nFIGHT" % event.round_number, 0.9)
        CombatEvent.EventType.KO:
            show_message("KO", 0.8)
        CombatEvent.EventType.TIME_UP:
            show_message("TIME UP", 0.9)
        CombatEvent.EventType.ROUND_ENDED:
            if event.round_result == RoundController.RoundResult.DRAW:
                show_message("DRAW", 0.9)
            elif event.round_result == RoundController.RoundResult.P1_WIN:
                show_message("P1 WINS", 0.9)
            elif event.round_result == RoundController.RoundResult.P2_WIN:
                show_message("P2 WINS", 0.9)
        CombatEvent.EventType.MATCH_ENDED:
            show_message("P%d WINS\nMATCH OVER" % event.attacker_id, 1.5)

func sync_from_simulation(simulation: BattleSimulation) -> void:
    if simulation == null:
        return
    if simulation.round_controller.is_match_over() and visual_message_remaining <= 0.0:
        var winner := simulation.round_controller.match_winner
        if winner != RoundController.Participant.NONE:
            show_message("P%d WINS\nMATCH OVER" % winner, 1.5)

func show_message(text_value: String, duration_seconds: float) -> void:
    visual_message = text_value
    visual_message_remaining = maxf(0.0, duration_seconds)
    if message_label != null:
        message_label.text = text_value

func reset_overlay() -> void:
    visual_message = ""
    visual_message_remaining = 0.0
    if message_label != null:
        message_label.text = ""
