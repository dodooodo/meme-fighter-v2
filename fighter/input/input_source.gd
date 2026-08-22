# Responsibility: Abstract source that produces normalized InputFrame values.
# Owns: source-specific sampling contract only.
# Does NOT own: combat logic, parsing, movement, state transitions.
# Dependencies: InputFrame.
class_name InputSource
extends RefCounted

func sample(frame_number: int) -> InputFrame:
    push_error("InputSource.sample() must be overridden")
    return InputFrame.neutral(frame_number)

func reset() -> void:
    pass
