# Responsibility: Deterministic geometry checks for strike contacts and grounded pushboxes.
class_name CollisionSystem
extends RefCounted

func build_strike_contacts(attacker: Fighter, defender: Fighter) -> Array[StrikeContact]:
    var contacts: Array[StrikeContact] = []
    if attacker == null or defender == null or attacker.combatant.is_ko or attacker.combatant.hitstop_remaining > 0:
        return contacts
    if defender.combatant.is_ko or not defender.state_machine.is_strike_target():
        return contacts
    var ids := attacker.hitbox_owner.active_hit_ids(attacker.move_runner)
    for hit_id in ids:
        if not attacker.hitbox_owner.can_hit_defender(attacker.move_runner.attack_instance_id, defender.fighter_id, hit_id):
            continue
        var attack_rect := attacker.hitbox_owner.active_hitbox_rect_for_hit(attacker.position_pixels(), attacker.movement_motor.facing, attacker.move_runner, hit_id)
        var hurt_rect := defender.hitbox_owner.hurtbox_rect(defender.position_pixels(), defender.movement_motor.facing, defender.move_runner)
        if not attack_rect.intersects(hurt_rect):
            continue
        var overlap := attack_rect.intersection(hurt_rect)
        var contact := StrikeContact.new()
        contact.attacker_id = attacker.fighter_id
        contact.defender_id = defender.fighter_id
        contact.move_id = attacker.move_runner.current_move_id()
        contact.attack_instance_id = attacker.move_runner.attack_instance_id
        contact.hit_id = hit_id
        contact.hit_position = overlap.get_center()
        contact.incoming_direction_x = 1 if attacker.movement_motor.sim_position.x >= defender.movement_motor.sim_position.x else -1
        contacts.append(contact)
    contacts.sort_custom(func(a: StrikeContact, b: StrikeContact) -> bool: return a.hit_id < b.hit_id)
    return contacts

func build_strike_contact(attacker: Fighter, defender: Fighter) -> StrikeContact:
    var contacts := build_strike_contacts(attacker, defender)
    return contacts[0] if not contacts.is_empty() else null

func apply_clash_priority(contacts: Array[StrikeContact], fighter_a: Fighter, fighter_b: Fighter) -> Array[StrikeContact]:
    # When both active body hitboxes connect on the same pre-apply frame, higher authored clash priority wins.
    # Equal priority preserves the deterministic trade. This is generic move data, never character-ID logic.
    if contacts.is_empty() or fighter_a == null or fighter_b == null:
        return contacts
    var a_contacts: Array[StrikeContact] = []
    var b_contacts: Array[StrikeContact] = []
    for contact: StrikeContact in contacts:
        if contact.attacker_id == fighter_a.fighter_id and contact.defender_id == fighter_b.fighter_id:
            a_contacts.append(contact)
        elif contact.attacker_id == fighter_b.fighter_id and contact.defender_id == fighter_a.fighter_id:
            b_contacts.append(contact)
    if a_contacts.is_empty() or b_contacts.is_empty():
        return contacts
    var priority_a := _highest_contact_priority(a_contacts, fighter_a)
    var priority_b := _highest_contact_priority(b_contacts, fighter_b)
    if priority_a == priority_b:
        return contacts
    var winner_id := fighter_a.fighter_id if priority_a > priority_b else fighter_b.fighter_id
    var filtered: Array[StrikeContact] = []
    for contact: StrikeContact in contacts:
        if contact.attacker_id == winner_id:
            filtered.append(contact)
    return filtered

func _highest_contact_priority(contacts: Array[StrikeContact], attacker: Fighter) -> int:
    var best := -2147483648
    for contact: StrikeContact in contacts:
        var move := attacker.move_registry.get_move(contact.move_id)
        var priority := move.clash_priority if move != null else 0
        if move != null:
            var payload = move.payload_for_hit_id(contact.hit_id)
            if payload is MoveHitData:
                priority = maxi(priority, payload.clash_priority)
        best = maxi(best, priority)
    return best

func resolve_pushboxes(a: Fighter, b: Fighter, stage_left_units: int, stage_right_units: int) -> void:
    if a.movement_motor.is_airborne() or b.movement_motor.is_airborne(): return
    var rect_a := a.hitbox_owner.pushbox_rect(a.position_pixels(), a.movement_motor.facing)
    var rect_b := b.hitbox_owner.pushbox_rect(b.position_pixels(), b.movement_motor.facing)
    if not rect_a.intersects(rect_b): return
    var overlap := rect_a.intersection(rect_b)
    if overlap.size.x <= 0.0: return
    var separation_units := maxi(1, int(ceil(overlap.size.x * float(SimulationUnits.UNITS_PER_PIXEL))))
    var a_is_left := a.movement_motor.sim_position.x <= b.movement_motor.sim_position.x
    var dir_a := -1 if a_is_left else 1
    var dir_b := -dir_a
    var desired_a := separation_units / 2
    var desired_b := separation_units - desired_a
    var room_a := _room_in_direction(a, dir_a, stage_left_units, stage_right_units)
    var move_a := mini(desired_a, room_a)
    var remaining := separation_units - move_a
    var room_b := _room_in_direction(b, dir_b, stage_left_units, stage_right_units)
    var move_b := mini(maxi(desired_b, remaining), room_b)
    remaining = separation_units - move_a - move_b
    if remaining > 0:
        var extra_a := mini(remaining, maxi(0, room_a - move_a)); move_a += extra_a; remaining -= extra_a
    if remaining > 0:
        move_b += mini(remaining, maxi(0, room_b - move_b))
    a.movement_motor.translate_x_units(dir_a * move_a)
    b.movement_motor.translate_x_units(dir_b * move_b)

func _room_in_direction(fighter: Fighter, direction: int, stage_left_units: int, stage_right_units: int) -> int:
    return maxi(0, fighter.movement_motor.sim_position.x - stage_left_units) if direction < 0 else maxi(0, stage_right_units - fighter.movement_motor.sim_position.x)
