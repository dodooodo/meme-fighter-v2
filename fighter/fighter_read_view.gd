# Responsibility: Build a copied, primitive observation of current Fighter state.
# Owns: read-view field projection only; no cached or authoritative state.
# Does NOT own: gameplay mutation, physics, statuses, modes, resources, snapshot, replay, or hashing.
# Dependencies: Fighter and its existing authoritative components.
class_name FighterReadView
extends RefCounted

static func capture(fighter: Fighter) -> Dictionary:
    if fighter == null:
        return {}
    var current_move := fighter.move_runner.current_move
    var resource_values := fighter.resources.capture_values()
    var resource_total := 0
    for value: Variant in resource_values.values():
        resource_total += int(value)
    return {
        "fighter_id": fighter.fighter_id,
        "character_id": fighter.data.id if fighter.data != null else &"",
        "grounded": fighter.is_grounded(),
        "airborne": fighter.is_airborne(),
        "position_units": fighter.movement_motor.sim_position,
        "facing": fighter.movement_motor.facing,
        "hp": fighter.combatant.hp,
        "max_hp": fighter.combatant.max_hp,
        "meter": fighter.meter.get_value(),
        "is_ko": fighter.combatant.is_ko,
        "hitstun_remaining": fighter.combatant.hitstun_remaining,
        "blockstun_remaining": fighter.combatant.blockstun_remaining,
        "hitstop_remaining": fighter.combatant.hitstop_remaining,
        "state_id": fighter.state_machine.state,
        "state_name": fighter.state_machine.state_name(),
        "guarding": fighter.state_machine.is_guarding(),
        "current_move_running": fighter.move_runner.is_running(),
        "current_move_id": fighter.move_runner.current_move_id(),
        "current_move_frame": fighter.move_runner.move_frame,
        "current_move_phase": fighter.move_runner.phase(),
        "current_move_hit_level": current_move.hit_level if current_move != null else -1,
        "attack_instance_id": fighter.move_runner.attack_instance_id,
        "active_mode_id": fighter.get_active_mode_id(),
        "mode_remaining_frames": fighter.get_mode_remaining_frames(),
        "guard_allowed": fighter.mode.guard_allowed(),
        "mode": fighter.mode.capture_state(),
        "resources": resource_values,
        "resource_total": resource_total,
        "statuses": fighter.statuses.capture_state(),
        "combo_hit_count": fighter.combo_scaling.hit_count,
        "combo_damage": fighter.combo_scaling.combo_damage,
        "combo_scale_percent": fighter.combo_scaling.current_scale_percent,
        "dash_cancel_count": fighter.combo_scaling.dash_cancel_count,
        "charge_frames": fighter.state_machine.charge_frames,
        "charge_level": fighter.state_machine.charge_level(fighter.move_registry),
        "throw_protection_frames": fighter.state_machine.throw_protection_remaining,
        "backstep_throw_invulnerable": fighter.state_machine.has_backstep_throw_invulnerability(),
        "throw_tech_pending": fighter.state_machine.throw_tech_pending,
    }
