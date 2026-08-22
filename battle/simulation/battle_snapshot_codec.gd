# Responsibility: Battle-level snapshot/restore coordinator over RoundController, Fighters, and ProjectileSystem state.
# Event queue/replay tooling policy: presentation events and ReplayRecorder/InputSource state are not gameplay snapshot state.
class_name BattleSnapshotCodec
extends RefCounted

static func capture(simulation: BattleSimulation) -> BattleStateSnapshot:
    var snapshot := BattleStateSnapshot.new()
    snapshot.frame_number = simulation.frame_number
    snapshot.round_state = simulation.round_controller.capture_snapshot()
    snapshot.fighter_a = FighterSnapshotCodec.capture(simulation.fighter_a)
    snapshot.fighter_b = FighterSnapshotCodec.capture(simulation.fighter_b)
    snapshot.next_projectile_instance_serial = simulation.projectile_system.next_projectile_instance_serial
    snapshot.projectiles = simulation.projectile_system.capture_snapshots()
    snapshot.next_temporary_entity_serial = simulation.temporary_entity_system.next_instance_serial
    snapshot.temporary_entities = simulation.temporary_entity_system.capture_state()
    return snapshot

static func restore(simulation: BattleSimulation, snapshot: BattleStateSnapshot) -> bool:
    if simulation == null or snapshot == null or snapshot.version != BattleStateSnapshot.VERSION:
        return false
    if snapshot.round_state == null or not simulation.round_controller.validate_restore_snapshot(snapshot.round_state):
        push_error("Battle snapshot round/rules compatibility validation failed")
        return false
    # Preflight every immutable compatibility/data-rehydration dependency before mutating runtime state.
    if not FighterSnapshotCodec.is_compatible(simulation.fighter_a, snapshot.fighter_a):
        return FighterSnapshotCodec.restore(simulation.fighter_a, snapshot.fighter_a)
    if not FighterSnapshotCodec.is_compatible(simulation.fighter_b, snapshot.fighter_b):
        return FighterSnapshotCodec.restore(simulation.fighter_b, snapshot.fighter_b)
    if not simulation.projectile_system.validate_restore_snapshots(
        snapshot.projectiles,
        snapshot.next_projectile_instance_serial,
        simulation.fighter_a,
        simulation.fighter_b
    ):
        push_error("Battle snapshot projectile compatibility validation failed")
        return false
    if not simulation.temporary_entity_system.validate_restore_state(snapshot.temporary_entities, snapshot.next_temporary_entity_serial):
        push_error("Battle snapshot temporary entity compatibility validation failed")
        return false

    if not FighterSnapshotCodec.restore(simulation.fighter_a, snapshot.fighter_a):
        return false
    if not FighterSnapshotCodec.restore(simulation.fighter_b, snapshot.fighter_b):
        return false
    if not simulation.projectile_system.restore_snapshots(
        snapshot.projectiles,
        snapshot.next_projectile_instance_serial,
        simulation.fighter_a,
        simulation.fighter_b
    ):
        return false
    if not simulation.temporary_entity_system.restore_state(snapshot.temporary_entities, snapshot.next_temporary_entity_serial):
        return false
    if not simulation.round_controller.restore_snapshot(snapshot.round_state):
        return false
    simulation.frame_number = snapshot.frame_number
    simulation.clear_pending_presentation_events()
    return true
