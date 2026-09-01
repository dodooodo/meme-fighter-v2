# Responsibility: Deterministic 1v1 outgoing-combo accounting and canonical damage scaling.
# Owns: hit count, repeated-Light count, combo damage, per-combo movement-cancel budget.
# Does NOT own: collision, HP mutation, MoveData, input, presentation, opponent state transitions.
# Dependencies: integer arithmetic only. The owning Fighter resets it when the defender regains actionable control.
class_name ComboScalingRuntime
extends RefCounted

const SCALE_BY_HIT_PERCENT: Array[int] = [100, 90, 80, 70, 60, 50]
const COMBO_SCALE_FLOOR_PERCENT: int = 40
const REPEATED_LIGHT_SCALE_PERCENT: Array[int] = [100, 90, 80]
const REPEATED_LIGHT_FLOOR_PERCENT: int = 70
const COMBO_ULTIMATE_INITIAL_PRORATION_PERCENT: int = 75

var active_defender_id: int = 0
var hit_count: int = 0
var repeated_light_count: int = 0
var combo_damage: int = 0
var current_scale_percent: int = 100
var dash_cancel_count: int = 0

func reset() -> void:
    active_defender_id = 0
    hit_count = 0
    repeated_light_count = 0
    combo_damage = 0
    current_scale_percent = 100
    dash_cancel_count = 0

func preview_scale_percent(defender_id: int, repeated_light: bool, combo_ultimate: bool) -> int:
    var sequence_index := hit_count if active_defender_id in [0, defender_id] else 0
    var scale := _hit_scale_percent(sequence_index)
    if repeated_light:
        var light_index := repeated_light_count if active_defender_id in [0, defender_id] else 0
        scale = _mul_percent(scale, _light_scale_percent(light_index))
    if combo_ultimate and sequence_index > 0:
        scale = _mul_percent(scale, COMBO_ULTIMATE_INITIAL_PRORATION_PERCENT)
    return maxi(COMBO_SCALE_FLOOR_PERCENT, scale)

func scaled_damage(raw_damage: int, defender_id: int, repeated_light: bool, combo_ultimate: bool) -> int:
    if raw_damage <= 0:
        return 0
    var scale := preview_scale_percent(defender_id, repeated_light, combo_ultimate)
    # Deterministic round-half-up. Damage never becomes zero for a positive authored hit.
    return maxi(1, (raw_damage * scale + 50) / 100)

func register_confirmed_hit(defender_id: int, scaled_damage_value: int, repeated_light: bool, combo_ultimate: bool) -> void:
    if active_defender_id != 0 and active_defender_id != defender_id:
        reset()
    if active_defender_id == 0:
        active_defender_id = defender_id
    current_scale_percent = preview_scale_percent(defender_id, repeated_light, combo_ultimate)
    hit_count += 1
    if repeated_light:
        repeated_light_count += 1
    else:
        repeated_light_count = 0
    combo_damage += maxi(0, scaled_damage_value)

func can_use_dash_cancel(max_per_combo: int) -> bool:
    return max_per_combo <= 0 or dash_cancel_count < max_per_combo

func record_dash_cancel() -> void:
    dash_cancel_count += 1

func capture_state() -> Dictionary:
    return {
        "active_defender_id": active_defender_id,
        "hit_count": hit_count,
        "repeated_light_count": repeated_light_count,
        "combo_damage": combo_damage,
        "current_scale_percent": current_scale_percent,
        "dash_cancel_count": dash_cancel_count,
    }

func restore_state(value: Dictionary) -> bool:
    var defender_id := int(value.get("active_defender_id", 0))
    var hits := int(value.get("hit_count", 0))
    var lights := int(value.get("repeated_light_count", 0))
    var damage := int(value.get("combo_damage", 0))
    var scale := int(value.get("current_scale_percent", 100))
    var dash_cancels := int(value.get("dash_cancel_count", 0))
    if defender_id < 0 or hits < 0 or lights < 0 or damage < 0 or dash_cancels < 0:
        return false
    if scale < COMBO_SCALE_FLOOR_PERCENT or scale > 100:
        return false
    active_defender_id = defender_id
    hit_count = hits
    repeated_light_count = lights
    combo_damage = damage
    current_scale_percent = scale
    dash_cancel_count = dash_cancels
    return true

static func _hit_scale_percent(sequence_index: int) -> int:
    if sequence_index < SCALE_BY_HIT_PERCENT.size():
        return SCALE_BY_HIT_PERCENT[sequence_index]
    return COMBO_SCALE_FLOOR_PERCENT

static func _light_scale_percent(light_index: int) -> int:
    if light_index < REPEATED_LIGHT_SCALE_PERCENT.size():
        return REPEATED_LIGHT_SCALE_PERCENT[light_index]
    return REPEATED_LIGHT_FLOOR_PERCENT

static func _mul_percent(lhs: int, rhs: int) -> int:
    return (lhs * rhs + 50) / 100
