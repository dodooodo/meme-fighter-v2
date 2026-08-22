# Responsibility: Fixed-capacity circular buffer of recent InputFrame snapshots.
# Owns: at least 60 frames of input history plus exact circular order/cursor for snapshot restore.
# Does NOT own: device polling or command recognition.
# Dependencies: InputFrame.
class_name InputHistory
extends RefCounted

var capacity: int = 60
var _buffer: Array[InputFrame] = []
var _write_index: int = 0
var _count: int = 0

func _init(p_capacity: int = 60) -> void:
    capacity = maxi(1, p_capacity)
    _buffer.resize(capacity)

func clear() -> void:
    _buffer.clear()
    _buffer.resize(capacity)
    _write_index = 0
    _count = 0

func push(frame: InputFrame) -> void:
    _buffer[_write_index] = frame.copy()
    _write_index = (_write_index + 1) % capacity
    _count = mini(_count + 1, capacity)

func count() -> int:
    return _count

func write_index() -> int:
    return _write_index

func latest() -> InputFrame:
    return get_recent(0)

func get_recent(offset: int) -> InputFrame:
    if offset < 0 or offset >= _count:
        return null
    var index := (_write_index - 1 - offset + capacity) % capacity
    return _buffer[index]

func capture_slots() -> Array[InputFrame]:
    var copies: Array[InputFrame] = []
    copies.resize(capacity)
    for i in range(capacity):
        copies[i] = _buffer[i].copy() if _buffer[i] != null else null
    return copies

func restore_slots(p_capacity: int, p_write_index: int, p_count: int, slots: Array[InputFrame]) -> void:
    capacity = maxi(1, p_capacity)
    _buffer.clear()
    _buffer.resize(capacity)
    for i in range(mini(capacity, slots.size())):
        _buffer[i] = slots[i].copy() if slots[i] != null else null
    _write_index = clampi(p_write_index, 0, capacity - 1)
    _count = clampi(p_count, 0, capacity)

func debug_string(max_frames: int = 12) -> String:
    var parts: PackedStringArray = []
    var amount := mini(max_frames, _count)
    for i in range(amount - 1, -1, -1):
        var frame := get_recent(i)
        if frame == null:
            continue
        var token := "%d:" % frame.frame_number
        if frame.direction_x < 0:
            token += "<"
        elif frame.direction_x > 0:
            token += ">"
        else:
            token += "-"
        if frame.direction_y > 0:
            token += "^"
        elif frame.direction_y < 0:
            token += "v"
        if frame.is_pressed(InputFrame.InputButton.LIGHT):
            token += "L!"
        elif frame.is_held(InputFrame.InputButton.LIGHT):
            token += "L"
        if frame.is_pressed(InputFrame.InputButton.HEAVY):
            token += "H!"
        elif frame.is_held(InputFrame.InputButton.HEAVY):
            token += "H"
        parts.append(token)
    return " ".join(parts)
