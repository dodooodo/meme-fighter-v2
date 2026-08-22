# Responsibility: Random-access ReplayData -> normalized InputFrame provider using the existing InputSource contract.
# Owns: participant selection and diagnostic EOF state only.
# Does NOT own: gameplay interpretation, RoundController, CharacterData, MoveData, keyboard polling, mutable replay cursor truth.
class_name ReplayInputSource
extends InputSource

var replay: ReplayData
var participant_id: int = 1
var eof_reached: bool = false
var last_requested_frame: int = 0

func configure(p_replay: ReplayData, p_participant_id: int) -> bool:
    if p_replay == null or p_participant_id not in [1, 2]:
        return false
    replay = p_replay
    participant_id = p_participant_id
    reset()
    return true

func sample(frame_number: int) -> InputFrame:
    last_requested_frame = frame_number
    if replay == null:
        eof_reached = true
        return InputFrame.neutral(frame_number)
    var pair := replay.get_frame_pair(frame_number)
    if pair == null:
        if frame_number > replay.final_frame_number():
            eof_reached = true
        return InputFrame.neutral(frame_number)
    return pair.p1_input.copy() if participant_id == 1 else pair.p2_input.copy()

func reset() -> void:
    eof_reached = false
    last_requested_frame = 0
