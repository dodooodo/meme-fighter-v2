# Authoritative gameplay mode runtime.
class_name ModeComponent
extends RefCounted

var _definitions: Dictionary = {}
var active_mode_id: StringName = &""
var remaining_frames: int = 0
var mode_serial: int = 0
var start_frame: int = -1
var last_expired_mode_id: StringName = &""
var last_expired_exit_move_id: StringName = &""

func configure(mechanics: CharacterMechanicsData) -> void:
    _definitions.clear()
    if mechanics != null:
        for data: ModeData in mechanics.modes:
            if data != null and data.mode_id != &"":
                _definitions[data.mode_id] = data
    reset_for_round()

func reset_for_round() -> void:
    active_mode_id = &""
    remaining_frames = 0
    mode_serial = 0
    start_frame = -1
    last_expired_mode_id = &""
    last_expired_exit_move_id = &""

func active_data() -> ModeData:
    return _definitions.get(active_mode_id, null) as ModeData

func enter_mode(data: ModeData, frame_number: int) -> bool:
    if data == null or data.mode_id == &"":
        return false
    _definitions[data.mode_id] = data
    active_mode_id = data.mode_id
    remaining_frames = data.duration_frames
    mode_serial += 1
    start_frame = frame_number
    return true

func exit_mode() -> void:
    active_mode_id = &""
    remaining_frames = 0
    start_frame = -1

func tick(frozen_by_hitstop: bool, resources: FighterResourceComponent) -> bool:
    last_expired_mode_id = &""
    last_expired_exit_move_id = &""
    var data := active_data()
    if data == null:
        return false
    if data.exit_when_resource_zero_id != &"" and resources != null and resources.get_value(data.exit_when_resource_zero_id) <= 0:
        last_expired_mode_id = active_mode_id
        last_expired_exit_move_id = data.exit_move_id
        exit_mode()
        return true
    if remaining_frames > 0 and not (frozen_by_hitstop and data.freeze_during_hitstop):
        remaining_frames -= 1
        if remaining_frames <= 0:
            last_expired_mode_id = active_mode_id
            last_expired_exit_move_id = data.exit_move_id
            exit_mode()
            return true
    return false

func guard_allowed() -> bool:
    var data := active_data()
    return data.guard_allowed if data != null else true

func movement_permille(kind: StringName) -> int:
    var data := active_data()
    if data == null:
        return 1000
    match kind:
        &"walk_forward": return data.forward_walk_permille
        &"walk_back": return data.back_walk_permille
        &"dash": return data.dash_speed_permille
        &"backstep": return data.backstep_speed_permille
        &"air_forward": return data.air_forward_permille
        &"air_back": return data.air_back_permille
    return 1000

func resolve_move_id(canonical_id: StringName) -> StringName:
    var data := active_data()
    if data == null:
        return canonical_id
    for override: ModeMoveOverrideData in data.move_overrides:
        if override != null and override.canonical_move_id == canonical_id:
            return override.replacement_move_id
    return canonical_id

func enter(mode_id: StringName, duration_override: int = -1, frame_number: int = 0) -> bool:
    var data: ModeData = _definitions.get(mode_id, null)
    if data == null:
        return false
    if not enter_mode(data, frame_number):
        return false
    if duration_override >= 0:
        remaining_frames = duration_override
    return true

func exit() -> void:
    exit_mode()

func has_definition(mode_id: StringName) -> bool:
    return _definitions.has(mode_id)

func capture_state() -> Dictionary:
    return {
        "active_mode_id": String(active_mode_id),
        "remaining_frames": remaining_frames,
        "mode_serial": mode_serial,
        "start_frame": start_frame,
    }

func restore_state(value: Dictionary) -> bool:
    var id := StringName(str(value.get("active_mode_id", "")))
    if id != &"" and not _definitions.has(id): return false
    active_mode_id = id
    remaining_frames = maxi(0, int(value.get("remaining_frames", 0)))
    mode_serial = maxi(0, int(value.get("mode_serial", 0)))
    start_frame = int(value.get("start_frame", -1))
    last_expired_mode_id = &""
    last_expired_exit_move_id = &""
    return true
