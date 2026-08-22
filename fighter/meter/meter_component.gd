# Responsibility: Deterministic per-fighter integer super meter runtime state.
# Owns: current meter value and clamped gain/spend/reset operations.
# Does NOT own: HUD, move selection, combat outcome classification, CharacterData mutation, wall-clock timing.
# Dependencies: integer simulation values only.
class_name MeterComponent
extends RefCounted

const MIN_VALUE: int = 0
const MAX_VALUE: int = 100
# Revision: global gameplay tuning — positive meter gains are five times the authored value.
const GAIN_MULTIPLIER: int = 5

var _value: int = MIN_VALUE

func get_value() -> int:
    return _value

func gain(amount: int) -> void:
    if amount <= 0:
        return
    _value = clampi(_value + amount * GAIN_MULTIPLIER, MIN_VALUE, MAX_VALUE)

func can_spend(amount: int) -> bool:
    return amount >= 0 and _value >= amount

func spend(amount: int) -> bool:
    if not can_spend(amount):
        return false
    _value = clampi(_value - amount, MIN_VALUE, MAX_VALUE)
    return true

func reset() -> void:
    _value = MIN_VALUE

func restore_value(value: int) -> void:
    _value = clampi(value, MIN_VALUE, MAX_VALUE)

# Test/debug setup compatibility alias. Runtime systems should prefer gain/spend/reset.
func set_value(value: int) -> void:
    restore_value(value)
