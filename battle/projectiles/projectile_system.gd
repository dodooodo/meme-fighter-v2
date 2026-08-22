# Responsibility: Battle-owned deterministic projectile spawn/movement/geometry/lifecycle/snapshot runtime subsystem.
# Owns: active ProjectileRuntime array and deterministic next instance serial.
# Does NOT own: guard matrix, HP/meter mutation, fighter input, animation/VFX/SFX, Node physics, delta/Timer authority.
# Dependencies: Fighter read-only geometry/configuration, ProjectileRuntime/Contact/Snapshot, ProjectileSpawnData.
class_name ProjectileSystem
extends RefCounted

const INITIAL_INSTANCE_SERIAL: int = 1

var next_projectile_instance_serial: int = INITIAL_INSTANCE_SERIAL
var _active: Array[ProjectileRuntime] = []

func reset() -> void:
    reset_for_new_match()

func reset_for_new_match() -> void:
    _active.clear()
    next_projectile_instance_serial = INITIAL_INSTANCE_SERIAL

func clear_all() -> void:
    clear_active()

# Round cleanup clears detached entities but deliberately preserves the monotonic per-match serial.
func clear_active() -> void:
    _active.clear()

func clear_owner(owner_fighter_id: int) -> void:
    for i in range(_active.size() - 1, -1, -1):
        if _active[i].owner_fighter_id == owner_fighter_id:
            _active.remove_at(i)

func active_count() -> int:
    return _active.size()

func active_projectiles() -> Array[ProjectileRuntime]:
    return _active.duplicate()

func get_projectile(instance_id: int) -> ProjectileRuntime:
    for projectile: ProjectileRuntime in _active:
        if projectile.instance_id == instance_id:
            return projectile
    return null

func spawn_from_descriptor(owner: Fighter, source_move_id: StringName, spawn_index: int, descriptor: ProjectileSpawnData) -> ProjectileRuntime:
    if owner == null or descriptor == null or descriptor.projectile_data == null or not descriptor.projectile_data.is_valid():
        return null
    var projectile := ProjectileRuntime.new()
    var spawn_position := owner.movement_motor.sim_position + Vector2i(
        descriptor.spawn_offset_units.x * owner.movement_motor.facing,
        descriptor.spawn_offset_units.y
    )
    projectile.configure(
        next_projectile_instance_serial,
        owner.fighter_id,
        source_move_id,
        spawn_index,
        descriptor.projectile_data,
        spawn_position,
        owner.movement_motor.facing
    )
    next_projectile_instance_serial += 1
    _active.append(projectile)
    return projectile

func advance_existing(frozen_by_hitstop: bool) -> void:
    if frozen_by_hitstop:
        return
    for projectile: ProjectileRuntime in _active:
        if projectile.pending_despawn or projectile.projectile_data == null:
            continue
        projectile.position_units.x += projectile.projectile_data.velocity_x_units_per_tick * projectile.facing
        projectile.remaining_lifetime_frames -= 1

func build_contacts(fighter_a: Fighter, fighter_b: Fighter) -> Array[ProjectileContact]:
    var contacts: Array[ProjectileContact] = []
    for projectile: ProjectileRuntime in _active:
        if projectile.pending_despawn or projectile.projectile_data == null or projectile.remaining_lifetime_frames < 0:
            continue
        var owner := _fighter_by_id(projectile.owner_fighter_id, fighter_a, fighter_b)
        var defender := _opponent_for_owner(projectile.owner_fighter_id, fighter_a, fighter_b)
        if owner == null or defender == null or owner == defender:
            continue
        if defender.combatant.is_ko or not defender.state_machine.is_strike_target():
            continue
        if not projectile.can_contact(defender.fighter_id):
            continue
        var attack_rect := projectile.gameplay_rect()
        var hurt_rect := defender.hitbox_owner.hurtbox_rect(defender.position_pixels(), defender.movement_motor.facing)
        if not attack_rect.intersects(hurt_rect):
            continue
        var overlap := attack_rect.intersection(hurt_rect)
        var contact := ProjectileContact.new()
        contact.attacker_id = owner.fighter_id
        contact.defender_id = defender.fighter_id
        contact.move_id = projectile.source_move_id
        contact.attack_instance_id = projectile.instance_id
        contact.hit_id = 0
        contact.hit_position = overlap.get_center()
        # Crucial M5 contract: guard side comes from detached projectile world origin, never owner current position.
        contact.incoming_direction_x = 1 if projectile.position_units.x >= defender.movement_motor.sim_position.x else -1
        contact.projectile_instance_id = projectile.instance_id
        contact.spawn_index = projectile.spawn_index
        contact.projectile_id = projectile.projectile_id
        contacts.append(contact)
    return contacts

func mark_resolved_contact(projectile_instance_id: int, defender_id: int, result_type: int) -> void:
    var projectile := get_projectile(projectile_instance_id)
    if projectile == null:
        return
    var reason := &"HIT" if result_type == HitResult.ResultType.HIT else &"BLOCK"
    projectile.record_contact(defender_id, reason)

func cleanup_end_of_tick(fighter_a: Fighter, fighter_b: Fighter) -> Array[ProjectileRuntime]:
    var removed: Array[ProjectileRuntime] = []
    for i in range(_active.size() - 1, -1, -1):
        var projectile := _active[i]
        var owner := _fighter_by_id(projectile.owner_fighter_id, fighter_a, fighter_b)
        if owner == null:
            projectile.pending_despawn = true
            projectile.despawn_reason = &"INVALID_OWNER"
        elif owner.combatant.is_ko and not projectile.pending_despawn:
            projectile.pending_despawn = true
            projectile.despawn_reason = &"OWNER_KO"
        elif projectile.remaining_lifetime_frames <= 0 and not projectile.pending_despawn:
            projectile.pending_despawn = true
            projectile.despawn_reason = &"EXPIRE"
        if projectile.pending_despawn:
            removed.push_front(projectile)
            _active.remove_at(i)
    return removed

func capture_snapshots() -> Array[ProjectileSnapshot]:
    var snapshots: Array[ProjectileSnapshot] = []
    # _active is deterministic spawn/instance order; removal never reorders survivors.
    for projectile: ProjectileRuntime in _active:
        var s := ProjectileSnapshot.new()
        s.instance_id = projectile.instance_id
        s.owner_fighter_id = projectile.owner_fighter_id
        s.source_move_id = projectile.source_move_id
        s.spawn_index = projectile.spawn_index
        s.projectile_id = projectile.projectile_id
        s.position_units = projectile.position_units
        s.facing = projectile.facing
        s.remaining_lifetime_frames = projectile.remaining_lifetime_frames
        s.contacted_defender_ids = projectile.contacted_defender_ids.duplicate()
        s.pending_despawn = projectile.pending_despawn
        s.despawn_reason = projectile.despawn_reason
        snapshots.append(s)
    return snapshots

func validate_restore_snapshots(snapshots: Array[ProjectileSnapshot], next_serial: int, fighter_a: Fighter, fighter_b: Fighter) -> bool:
    if next_serial < INITIAL_INSTANCE_SERIAL:
        return false
    var last_instance_id := 0
    for s: ProjectileSnapshot in snapshots:
        if s == null or s.instance_id <= last_instance_id or s.instance_id >= next_serial:
            return false
        if (s.owner_fighter_id != 1 and s.owner_fighter_id != 2) or s.source_move_id == &"" or s.spawn_index < 0 or s.projectile_id == &"":
            return false
        if (s.facing != -1 and s.facing != 1) or s.remaining_lifetime_frames < 0:
            return false
        var owner := _fighter_by_id(s.owner_fighter_id, fighter_a, fighter_b)
        var data := _rehydrate_data(owner, s.source_move_id, s.spawn_index)
        if data == null or data.id != s.projectile_id:
            return false
        last_instance_id = s.instance_id
    return true

func restore_snapshots(snapshots: Array[ProjectileSnapshot], next_serial: int, fighter_a: Fighter, fighter_b: Fighter) -> bool:
    if not validate_restore_snapshots(snapshots, next_serial, fighter_a, fighter_b):
        push_error("Projectile snapshot restore rejected: invalid owner/source/spawn/projectile identity or serial ordering")
        return false
    var restored: Array[ProjectileRuntime] = []
    for s: ProjectileSnapshot in snapshots:
        var owner := _fighter_by_id(s.owner_fighter_id, fighter_a, fighter_b)
        var data := _rehydrate_data(owner, s.source_move_id, s.spawn_index)
        var projectile := ProjectileRuntime.new()
        projectile.configure(s.instance_id, s.owner_fighter_id, s.source_move_id, s.spawn_index, data, s.position_units, s.facing)
        projectile.remaining_lifetime_frames = s.remaining_lifetime_frames
        projectile.contacted_defender_ids = s.contacted_defender_ids.duplicate()
        projectile.pending_despawn = s.pending_despawn
        projectile.despawn_reason = s.despawn_reason
        restored.append(projectile)
    _active = restored
    next_projectile_instance_serial = next_serial
    return true

func _rehydrate_data(owner: Fighter, source_move_id: StringName, spawn_index: int) -> ProjectileData:
    if owner == null or owner.move_registry == null:
        return null
    var source_move := owner.move_registry.get_move(source_move_id)
    if source_move == null or spawn_index < 0 or spawn_index >= source_move.projectile_spawns.size():
        return null
    var descriptor: ProjectileSpawnData = source_move.projectile_spawns[spawn_index]
    if descriptor == null:
        return null
    return descriptor.projectile_data

func _fighter_by_id(fighter_id: int, fighter_a: Fighter, fighter_b: Fighter) -> Fighter:
    if fighter_a != null and fighter_a.fighter_id == fighter_id:
        return fighter_a
    if fighter_b != null and fighter_b.fighter_id == fighter_id:
        return fighter_b
    return null

func _opponent_for_owner(owner_id: int, fighter_a: Fighter, fighter_b: Fighter) -> Fighter:
    if fighter_a != null and fighter_a.fighter_id == owner_id:
        return fighter_b
    if fighter_b != null and fighter_b.fighter_id == owner_id:
        return fighter_a
    return null
