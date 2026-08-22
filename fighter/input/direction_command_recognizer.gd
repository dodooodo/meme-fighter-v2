# Responsibility: Stateless facing-relative double-tap command recognition over InputHistory.
# Owns: Forward-Neutral-Forward / Back-Neutral-Back leniency rules only.
# Does NOT own: keyboard input, fighter state transitions, movement, buffering, MoveData.
# Dependencies: InputHistory, InputFrame.
class_name DirectionCommandRecognizer
extends RefCounted

const TOTAL_WINDOW_FRAMES: int = 12
const MAX_NEUTRAL_GAP_FRAMES: int = 6

static func recognize_forward_dash(history: InputHistory, facing: int) -> bool:
    return _recognize(history, 1, facing)

static func recognize_backstep(history: InputHistory, facing: int) -> bool:
    return _recognize(history, -1, facing)

static func _recognize(history: InputHistory, wanted_relative: int, facing: int) -> bool:
    if history == null or history.count() < 3:
        return false
    var normalized_facing := -1 if facing < 0 else 1
    var current := history.get_recent(0)
    var previous := history.get_recent(1)
    if current == null or previous == null:
        return false
    if _relative_x(current, normalized_facing) != wanted_relative:
        return false
    # Second tap must be a distinct directional press, not a held direction.
    if _relative_x(previous, normalized_facing) == wanted_relative:
        return false

    var neutral_count := 0
    var offset := 1
    while offset < history.count() and offset <= TOTAL_WINDOW_FRAMES:
        var frame := history.get_recent(offset)
        if frame == null:
            return false
        var relative := _relative_x(frame, normalized_facing)
        if relative == 0:
            neutral_count += 1
            if neutral_count > MAX_NEUTRAL_GAP_FRAMES:
                return false
            offset += 1
            continue
        break

    if neutral_count <= 0 or neutral_count > MAX_NEUTRAL_GAP_FRAMES:
        return false
    if offset >= history.count() or offset > TOTAL_WINDOW_FRAMES:
        return false
    var prior_direction_frame := history.get_recent(offset)
    if prior_direction_frame == null or _relative_x(prior_direction_frame, normalized_facing) != wanted_relative:
        return false

    # Walk backward across the first held tap to find its press edge.
    var first_press_offset := offset
    while first_press_offset + 1 < history.count() and first_press_offset + 1 <= TOTAL_WINDOW_FRAMES:
        var older := history.get_recent(first_press_offset + 1)
        if older == null or _relative_x(older, normalized_facing) != wanted_relative:
            break
        first_press_offset += 1

    var first_press := history.get_recent(first_press_offset)
    if first_press == null:
        return false
    var before_first := history.get_recent(first_press_offset + 1)
    if before_first != null and _relative_x(before_first, normalized_facing) == wanted_relative:
        return false
    return current.frame_number - first_press.frame_number <= TOTAL_WINDOW_FRAMES

static func _relative_x(frame: InputFrame, facing: int) -> int:
    if frame.direction_x == 0:
        return 0
    return 1 if frame.direction_x == facing else -1
