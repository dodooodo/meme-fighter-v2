# Responsibility: Deterministic per-fighter integer super meter runtime state.
# Owns: current meter value and clamped gain/spend/reset operations.
# Does NOT own: HUD, move selection, combat outcome classification, CharacterData mutation, wall-clock timing.
# Dependencies: integer simulation values only.
class_name MeterComponent
extends RefCounted

const MIN_VALUE: int = 0
const MAX_VALUE: int = 100

var _value: int = MIN_VALUE
# Training-only debug policy; false in ordinary matches and excluded from Snapshot/Replay.
var training_infinite_meter: bool = false

func get_value() -> int:
    return _value

func gain(amount: int) -> void:
    if amount <= 0:
        return
    _value = clampi(_value + amount, MIN_VALUE, MAX_VALUE)

func can_spend(amount: int) -> bool:
    return amount >= 0 and (training_infinite_meter or _value >= amount)

func spend(amount: int) -> bool:
    if not can_spend(amount):
        return false
    if not training_infinite_meter:
        _value = clampi(_value - amount, MIN_VALUE, MAX_VALUE)
    return true

func reset() -> void:
    _value = MIN_VALUE

func restore_value(value: int) -> void:
    _value = clampi(value, MIN_VALUE, MAX_VALUE)

# Test/debug setup compatibility alias. Runtime systems should prefer gain/spend/reset.
func set_value(value: int) -> void:
    restore_value(value)
