# Canonically ordered deterministic timed status runtime.
class_name StatusEffectComponent
extends RefCounted

var _definitions: Dictionary = {}
var _states: Dictionary = {}
var _next_application_serial: int = 1

func configure(mechanics: CharacterMechanicsData) -> void:
    _definitions.clear()
    _states.clear()
    _next_application_serial = 1
    if mechanics == null:
        return
    for data: StatusEffectData in mechanics.statuses:
        if data != null and data.id != &"":
            _definitions[data.id] = data

func register_definition(data: StatusEffectData) -> void:
    if data != null and data.id != &"":
        _definitions[data.id] = data

func reset_for_round() -> void:
    _states.clear()
    _next_application_serial = 1

func has_status(id: StringName) -> bool:
    return _states.has(id)

func remaining_frames(id: StringName) -> int:
    var state: Dictionary = _states.get(id, {})
    return int(state.get("remaining", 0))

func application_serial(id: StringName) -> int:
    var state: Dictionary = _states.get(id, {})
    return int(state.get("serial", 0))

func extended_once(id: StringName) -> bool:
    var state: Dictionary = _states.get(id, {})
    return bool(state.get("extended_once", false))

func apply_status(data: StatusEffectData) -> bool:
    if data == null or data.id == &"":
        return false
    register_definition(data)
    if _states.has(data.id):
        var current: Dictionary = _states[data.id]
        match data.refresh_policy:
            StatusEffectData.RefreshPolicy.KEEP_LONGER:
                current["remaining"] = maxi(int(current["remaining"]), data.duration_frames)
            StatusEffectData.RefreshPolicy.REFRESH:
                current["remaining"] = data.duration_frames
            StatusEffectData.RefreshPolicy.REPLACE:
                current = _new_state(data)
        if data.stackable:
            current["stacks"] = mini(int(current.get("stacks", 1)) + 1, data.max_stacks)
        _states[data.id] = current
        return true
    _states[data.id] = _new_state(data)
    return true

func remove_status(id: StringName) -> bool:
    return _states.erase(id)

func consume_status(id: StringName) -> bool:
    return remove_status(id)

func extend_once(id: StringName, frames: int) -> bool:
    if not _states.has(id):
        return false
    var state: Dictionary = _states[id]
    if bool(state.get("extended_once", false)):
        return false
    state["remaining"] = maxi(0, int(state.get("remaining", 0)) + maxi(0, frames))
    state["extended_once"] = true
    _states[id] = state
    return true

func tick(frozen_by_hitstop: bool) -> void:
    var remove_ids: Array[StringName] = []
    for id: StringName in sorted_active_ids():
        var data: StatusEffectData = _definitions.get(id, null)
        if frozen_by_hitstop and data != null and data.freeze_during_hitstop:
            continue
        var state: Dictionary = _states[id]
        state["remaining"] = int(state.get("remaining", 0)) - 1
        if int(state["remaining"]) <= 0:
            remove_ids.append(id)
        else:
            _states[id] = state
    for id: StringName in remove_ids:
        _states.erase(id)

func movement_permille(kind: StringName) -> int:
    var result := 1000
    for id: StringName in sorted_active_ids():
        var data: StatusEffectData = _definitions.get(id, null)
        if data == null:
            continue
        var value := 1000
        if kind == &"walk":
            value = data.walk_speed_permille
        elif kind == &"dash":
            value = data.dash_speed_permille
        elif kind == &"backstep":
            value = data.backstep_speed_permille
        result = (result * value) / 1000
    return result

func sorted_active_ids() -> Array[StringName]:
    var ids: Array[StringName] = []
    for key: Variant in _states.keys():
        ids.append(StringName(key))
    ids.sort()
    return ids

func next_application_serial() -> int:
    return _next_application_serial

func capture_state() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for id: StringName in sorted_active_ids():
        var state: Dictionary = _states[id]
        out.append({
            "id": String(id),
            "remaining": int(state.get("remaining", 0)),
            "serial": int(state.get("serial", 0)),
            "stacks": int(state.get("stacks", 1)),
            "extended_once": bool(state.get("extended_once", false)),
        })
    return out

func restore_state(states: Array[Dictionary], next_serial: int) -> bool:
    var restored: Dictionary = {}
    var last_id := ""
    for state: Dictionary in states:
        var id := StringName(str(state.get("id", "")))
        if id == &"" or not _definitions.has(id) or restored.has(id):
            return false
        if last_id != "" and String(id) <= last_id:
            return false
        var remaining := int(state.get("remaining", 0))
        if remaining <= 0:
            return false
        restored[id] = {
            "remaining": remaining,
            "serial": int(state.get("serial", 0)),
            "stacks": int(state.get("stacks", 1)),
            "extended_once": bool(state.get("extended_once", false)),
        }
        last_id = String(id)
    _states = restored
    _next_application_serial = maxi(1, next_serial)
    return true

func _new_state(data: StatusEffectData) -> Dictionary:
    var state := {
        "remaining": data.duration_frames,
        "serial": _next_application_serial,
        "stacks": 1,
        "extended_once": false,
    }
    _next_application_serial += 1
    return state

# Short generic aliases used by gameplay systems.
func apply(data: StatusEffectData) -> bool:
    return apply_status(data)

func apply_defined(id: StringName) -> bool:
    var data: StatusEffectData = _definitions.get(id, null)
    return apply_status(data)

func remove(id: StringName) -> bool:
    return remove_status(id)
