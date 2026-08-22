# Responsibility: Deterministic single-slot buffer for contextual offensive ActionIntent snapshots.
# Owns: copied buffered intent, expiry frame, latest-intent-wins, peek/consume/clear semantics.
# Does NOT own: MoveData, MoveRegistry, MoveRunner, fighter state legality, input devices, HP, collision, animation.
# Dependencies: ActionIntent, InputFrame action identifiers only.
class_name InputBuffer
extends RefCounted

const DEFAULT_BUFFER_FRAMES: int = 5

var _buffered_intent: ActionIntent = null
var _expiry_frame: int = -1

func buffer_intent(intent: ActionIntent, window_frames: int = DEFAULT_BUFFER_FRAMES) -> bool:
    if intent == null or not is_supported_action_intent(intent):
        return false
    _buffered_intent = intent.copy()
    _expiry_frame = _buffered_intent.source_frame + maxi(0, window_frames)
    return true

func expire_if_needed(current_frame: int) -> void:
    if _buffered_intent != null and current_frame > _expiry_frame:
        clear()

func has_pending(current_frame: int) -> bool:
    return _buffered_intent != null and current_frame <= _expiry_frame

func peek_intent(current_frame: int) -> ActionIntent:
    if not has_pending(current_frame):
        return null
    return _buffered_intent.copy()

func snapshot_intent() -> ActionIntent:
    return _buffered_intent.copy() if _buffered_intent != null else null

func restore_snapshot(intent: ActionIntent, expiry: int) -> void:
    _buffered_intent = intent.copy() if intent != null else null
    _expiry_frame = expiry if _buffered_intent != null else -1

func consume_intent(current_frame: int) -> ActionIntent:
    var intent := peek_intent(current_frame)
    if intent != null:
        clear()
    return intent

func clear() -> void:
    _buffered_intent = null
    _expiry_frame = -1

func source_frame() -> int:
    return _buffered_intent.source_frame if _buffered_intent != null else -1

func expiry_frame() -> int:
    return _expiry_frame

func remaining_frames(current_frame: int) -> int:
    if not has_pending(current_frame):
        return 0
    return maxi(0, _expiry_frame - current_frame)

func buffered_action_name(current_frame: int) -> String:
    var intent := peek_intent(current_frame)
    if intent == null:
        return "NONE"
    match intent.action_button:
        InputFrame.InputButton.LIGHT:
            return "LIGHT"
        InputFrame.InputButton.HEAVY:
            return "HEAVY"
        InputFrame.InputButton.SPECIAL:
            return "SPECIAL"
        InputFrame.InputButton.ULTIMATE:
            return "ULTIMATE"
        _:
            return "NONE"

static func is_supported_action_intent(intent: ActionIntent) -> bool:
    if intent == null:
        return false
    return intent.action_button in [
        InputFrame.InputButton.LIGHT,
        InputFrame.InputButton.HEAVY,
        InputFrame.InputButton.SPECIAL,
        InputFrame.InputButton.ULTIMATE,
    ]

static func is_supported_normal_intent(intent: ActionIntent) -> bool:
    # Compatibility helper for older tests/callers.
    if intent == null:
        return false
    return intent.action_button == InputFrame.InputButton.LIGHT or intent.action_button == InputFrame.InputButton.HEAVY
