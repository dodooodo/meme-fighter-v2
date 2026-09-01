# Responsibility: Runtime combat status of one fighter.
# Owns: HP, hitstun, blockstun, hitstop, KO flag, horizontal/vertical knockback velocity.
# Does NOT own: movement integration, move timelines, collision, presentation, throw/knockdown timers.
# Dependencies: none.
class_name Combatant
extends RefCounted

var max_hp: int = 1000
var hp: int = 1000
var hitstun_remaining: int = 0
var blockstun_remaining: int = 0
var hitstop_remaining: int = 0
var knockback_velocity_x_units: int = 0
var knockback_velocity_y_units: int = 0
var is_ko: bool = false
var last_result_type: int = -1
# Training-only debug policy; false in all ordinary matches and excluded from Snapshot/Replay.
var training_infinite_hp: bool = false

func configure(p_max_hp: int) -> void:
    max_hp = maxi(1, p_max_hp)
    reset()

func reset() -> void:
    hp = max_hp
    hitstun_remaining = 0
    blockstun_remaining = 0
    hitstop_remaining = 0
    knockback_velocity_x_units = 0
    knockback_velocity_y_units = 0
    is_ko = false
    last_result_type = -1

func apply_attacker_hitstop(frames: int) -> void:
    hitstop_remaining = maxi(hitstop_remaining, maxi(0, frames))

func receive_hit(damage: int, hitstun: int, hitstop: int, knockback_x: int, knockback_y: int = 0) -> void:
    if is_ko:
        return
    hp = clampi(hp - maxi(0, damage), 1 if training_infinite_hp else 0, max_hp)
    hitstun_remaining = maxi(0, hitstun)
    blockstun_remaining = 0
    hitstop_remaining = maxi(hitstop_remaining, maxi(0, hitstop))
    knockback_velocity_x_units = knockback_x
    knockback_velocity_y_units = knockback_y
    if hp <= 0:
        is_ko = true

func receive_throw_damage(damage: int, hitstop: int) -> void:
    if is_ko:
        return
    hp = clampi(hp - maxi(0, damage), 1 if training_infinite_hp else 0, max_hp)
    hitstun_remaining = 0
    blockstun_remaining = 0
    hitstop_remaining = maxi(hitstop_remaining, maxi(0, hitstop))
    knockback_velocity_x_units = 0
    knockback_velocity_y_units = 0
    if hp <= 0:
        is_ko = true

func receive_block(chip_damage: int, blockstun: int, hitstop: int) -> void:
    if is_ko:
        return
    hp = clampi(hp - maxi(0, chip_damage), 1 if training_infinite_hp else 0, max_hp)
    hitstun_remaining = 0
    blockstun_remaining = maxi(0, blockstun)
    hitstop_remaining = maxi(hitstop_remaining, maxi(0, hitstop))
    knockback_velocity_x_units = 0
    knockback_velocity_y_units = 0
    if hp <= 0:
        is_ko = true

func tick_statuses() -> void:
    if hitstop_remaining > 0:
        hitstop_remaining -= 1
        return
    if hitstun_remaining > 0:
        hitstun_remaining -= 1
    if blockstun_remaining > 0:
        blockstun_remaining -= 1

func can_start_normal_move() -> bool:
    # Compatibility name retained from M2.1/M2.2 tests.
    return can_act()

func can_act() -> bool:
    return not is_ko and hitstun_remaining <= 0 and blockstun_remaining <= 0 and hitstop_remaining <= 0
