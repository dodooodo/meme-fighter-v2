# Screen-space round/match messaging. Visual duration never gates RoundController.
class_name RoundPresentationOverlay
extends Control

@onready var message_label: Label = $Message
var visual_message: String = ""
var visual_message_remaining: float = 0.0
var visual_color: Color = Color(1.0, 0.95, 0.72, 1.0)

func _process(delta: float) -> void:
    if visual_message_remaining > 0.0:
        visual_message_remaining = maxf(0.0, visual_message_remaining - delta)
        if visual_message_remaining <= 0.0 and message_label != null:
            message_label.text = ""
            message_label.scale = Vector2.ONE

func present_event(event: CombatEvent) -> void:
    if event == null:
        return
    match event.type:
        CombatEvent.EventType.ROUND_STARTED:
            show_message("ROUND %d\nFIGHT" % event.round_number, 0.9, Color(1.0, 0.95, 0.72, 1.0))
        CombatEvent.EventType.KO:
            show_message("KO", 0.8, Color(1.0, 0.32, 0.24, 1.0))
        CombatEvent.EventType.TIME_UP:
            show_message("TIME UP", 0.9, Color(0.72, 0.86, 1.0, 1.0))
        CombatEvent.EventType.ROUND_ENDED:
            if event.round_result == RoundController.RoundResult.DRAW:
                show_message("DRAW", 0.9, Color(0.82, 0.88, 0.96, 1.0))
            elif event.round_result == RoundController.RoundResult.P1_WIN:
                show_message("P1 WINS", 0.9, Color(1.0, 0.84, 0.36, 1.0))
            elif event.round_result == RoundController.RoundResult.P2_WIN:
                show_message("P2 WINS", 0.9, Color(1.0, 0.84, 0.36, 1.0))
        CombatEvent.EventType.MATCH_ENDED:
            show_message("P%d WINS\nMATCH OVER" % event.attacker_id, 1.5, Color(1.0, 0.82, 0.24, 1.0))

func sync_from_simulation(simulation: BattleSimulation) -> void:
    if simulation == null:
        return
    if simulation.round_controller.is_match_over() and visual_message_remaining <= 0.0:
        var winner := simulation.round_controller.match_winner
        if winner != RoundController.Participant.NONE:
            show_message("P%d WINS\nMATCH OVER" % winner, 1.5, Color(1.0, 0.82, 0.24, 1.0))

func show_message(text_value: String, duration_seconds: float, color_value: Color = Color(1.0, 0.95, 0.72, 1.0)) -> void:
    visual_message = text_value
    visual_message_remaining = maxf(0.0, duration_seconds)
    visual_color = color_value
    if message_label != null:
        message_label.text = text_value
        message_label.modulate = color_value
        message_label.scale = Vector2.ONE * 1.08

func reset_overlay() -> void:
    visual_message = ""
    visual_message_remaining = 0.0
    visual_color = Color(1.0, 0.95, 0.72, 1.0)
    if message_label != null:
        message_label.text = ""
        message_label.modulate = visual_color
        message_label.scale = Vector2.ONE
