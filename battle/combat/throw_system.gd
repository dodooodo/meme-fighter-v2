# Geometry-only generic throw/command-grab/ground-capture contact validation.
class_name ThrowSystem
extends RefCounted

func build_throw_contact(attacker: Fighter, defender: Fighter) -> ThrowContact:
    if attacker == null or defender == null or attacker.combatant.is_ko or attacker.combatant.hitstop_remaining > 0: return null
    if not attacker.hitbox_owner.has_active_throw_box(attacker.move_runner): return null
    var move := attacker.move_runner.current_move
    if move == null: return null
    if not defender.state_machine.is_throwable() or defender.movement_motor.is_airborne(): return null
    if move.throw_avoids_backstep and defender.state_machine.state == FighterStateMachine.State.BACKSTEP: return null
    if not attacker.hitbox_owner.can_hit_defender(attacker.move_runner.attack_instance_id, defender.fighter_id, 0): return null
    var throw_rect := attacker.hitbox_owner.active_throw_rect(attacker.position_pixels(), attacker.movement_motor.facing, attacker.move_runner)
    var target_rect := defender.hitbox_owner.hurtbox_rect(defender.position_pixels(), defender.movement_motor.facing, defender.move_runner)
    if not throw_rect.intersects(target_rect): return null
    var contact := ThrowContact.new(); contact.attacker_id = attacker.fighter_id; contact.defender_id = defender.fighter_id
    contact.move_id = attacker.move_runner.current_move_id(); contact.attack_instance_id = attacker.move_runner.attack_instance_id
    contact.hit_position = throw_rect.intersection(target_rect).get_center()
    return contact
