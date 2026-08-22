# Deterministic custom resource slots (face_actions, courage, resolve, etc.).
class_name FighterResourceComponent
extends RefCounted

var _data_by_id: Dictionary = {}
var _values: Dictionary = {}

func configure(mechanics: CharacterMechanicsData) -> void:
    _data_by_id.clear()
    _values.clear()
    if mechanics == null:
        return
    for data: FighterResourceData in mechanics.resources:
        if data == null or data.resource_id == &"":
            continue
        _data_by_id[data.resource_id] = data
        _values[data.resource_id] = clampi(data.round_start_value, data.min_value, data.max_value)

func reset_for_round() -> void:
    for id: StringName in sorted_ids():
        var data: FighterResourceData = _data_by_id[id]
        if data.reset_on_round:
            _values[id] = clampi(data.round_start_value, data.min_value, data.max_value)

func has(id: StringName) -> bool:
    return _data_by_id.has(id)

func get_value(id: StringName) -> int:
    return int(_values.get(id, 0))

func set_value(id: StringName, value: int) -> bool:
    if not _data_by_id.has(id):
        return false
    var data: FighterResourceData = _data_by_id[id]
    _values[id] = clampi(value, data.min_value, data.max_value)
    return true

func gain(id: StringName, amount: int) -> bool:
    return set_value(id, get_value(id) + amount)

func spend(id: StringName, amount: int) -> bool:
    if amount <= 0:
        return true
    if not can_spend(id, amount):
        return false
    return set_value(id, get_value(id) - amount)

func can_spend(id: StringName, amount: int) -> bool:
    if amount <= 0:
        return true
    if not _data_by_id.has(id):
        return false
    var data: FighterResourceData = _data_by_id[id]
    return get_value(id) - amount >= data.min_value

func sorted_ids() -> Array[StringName]:
    var ids: Array[StringName] = []
    for key: Variant in _data_by_id.keys():
        ids.append(StringName(key))
    ids.sort()
    return ids

func capture_values() -> Dictionary:
    var out: Dictionary = {}
    for id: StringName in sorted_ids():
        out[String(id)] = get_value(id)
    return out

func restore_values(values: Dictionary) -> bool:
    for id: StringName in sorted_ids():
        var key := String(id)
        if not values.has(key):
            return false
        if not set_value(id, int(values[key])):
            return false
    return values.size() == _data_by_id.size()

func display_summary() -> String:
    var parts: PackedStringArray = []
    for id: StringName in sorted_ids():
        var data: FighterResourceData = _data_by_id[id]
        if data.display_to_hud:
            parts.append("%s=%d" % [String(id), get_value(id)])
    return " ".join(parts)
