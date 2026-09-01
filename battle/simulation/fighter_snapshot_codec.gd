# Responsibility: Encode/decode Fighter component runtime state to primitive/value snapshots.
# Owns: snapshot boundary mapping only; gameplay logic remains in the source components.
# Does NOT own: simulation stepping, presentation, networking, static Resource serialization.
class_name FighterSnapshotCodec
extends RefCounted

static func capture(fighter: Fighter) -> FighterStateSnapshot:
    var s := FighterStateSnapshot.new()
    s.fighter_id = fighter.fighter_id
    s.character_id = fighter.data.id if fighter.data != null else &""

    s.sim_position = fighter.movement_motor.sim_position
    s.velocity_units = fighter.movement_motor.velocity_units
    s.facing = fighter.movement_motor.facing
    s.landed_this_frame = fighter.movement_motor.landed_this_frame

    s.hp = fighter.combatant.hp
    s.hitstun_remaining = fighter.combatant.hitstun_remaining
    s.blockstun_remaining = fighter.combatant.blockstun_remaining
    s.hitstop_remaining = fighter.combatant.hitstop_remaining
    s.knockback_velocity_x_units = fighter.combatant.knockback_velocity_x_units
    s.knockback_velocity_y_units = fighter.combatant.knockback_velocity_y_units
    s.is_ko = fighter.combatant.is_ko
    s.last_result_type = fighter.combatant.last_result_type
    s.meter_value = fighter.meter.get_value()

    s.root_state = fighter.state_machine.root_state
    s.state = fighter.state_machine.state
    s.previous_state = fighter.state_machine.previous_state
    s.guard_posture = fighter.state_machine.guard_posture
    s.air_attack_available = fighter.state_machine.air_attack_available
    s.landing_remaining = fighter.state_machine.landing_remaining
    s.dash_move_remaining = fighter.state_machine.dash_move_remaining
    s.dash_recovery_remaining = fighter.state_machine.dash_recovery_remaining
    s.dash_elapsed_frames = fighter.state_machine.dash_elapsed_frames
    s.throw_protection_remaining = fighter.state_machine.throw_protection_remaining
    s.thrown_remaining = fighter.state_machine.thrown_remaining
    s.knockdown_remaining = fighter.state_machine.knockdown_remaining
    s.getup_remaining = fighter.state_machine.getup_remaining
    s.pending_knockdown_frames = fighter.state_machine.pending_knockdown_frames
    s.pending_getup_frames = fighter.state_machine.pending_getup_frames
    s.throw_tech_pending = fighter.state_machine.throw_tech_pending
    s.jump_started_this_tick = fighter.state_machine.jump_started_this_tick
    s.jump_buffer_expiry_frame = fighter.state_machine.jump_buffer_expiry_frame
    s.charge_frames = fighter.state_machine.charge_frames
    s.charge_entry_move_id = fighter.state_machine.charge_entry_move_id
    s.charge_locked_facing = fighter.state_machine.charge_locked_facing
    s.charge_early_release_requested = fighter.state_machine.charge_early_release_requested

    s.current_move_id = fighter.move_runner.current_move_id()
    s.move_frame = fighter.move_runner.move_frame
    s.attack_instance_id = fighter.move_runner.attack_instance_id
    s.next_attack_instance_serial = fighter.move_runner.instance_serial()
    s.move_connected_hit = fighter.move_runner.connected_hit
    s.move_connected_block = fighter.move_runner.connected_block
    s.move_spawned_projectile_indices = fighter.move_runner.spawned_projectile_indices()
    s.move_activation_resource_values = fighter.move_runner.activation_resource_values()

    s.tracked_attack_instance_id = fighter.hitbox_owner.tracked_attack_instance_id()
    s.contacted_defender_ids = fighter.hitbox_owner.contacted_defender_ids()
    s.contacted_hit_keys = fighter.hitbox_owner.contacted_hit_keys()
    s.resource_values = fighter.resources.capture_values()
    s.status_states = fighter.statuses.capture_state()
    s.next_status_application_serial = fighter.statuses.next_application_serial()
    s.mode_state = fighter.mode.capture_state()
    s.mechanics_state = fighter.mechanics_runtime.capture_state()
    s.combo_state = fighter.combo_scaling.capture_state()

    s.buffered_intent = ActionIntentSnapshot.from_intent(fighter.input_buffer.snapshot_intent())
    s.input_buffer_expiry_frame = fighter.input_buffer.expiry_frame()

    s.input_history_capacity = fighter.input_history.capacity
    s.input_history_write_index = fighter.input_history.write_index()
    s.input_history_count = fighter.input_history.count()
    var slots := fighter.input_history.capture_slots()
    s.input_history_slots.resize(slots.size())
    for i in range(slots.size()):
        s.input_history_slots[i] = InputFrameSnapshot.from_frame(slots[i])
    return s

static func is_compatible(fighter: Fighter, s: FighterStateSnapshot) -> bool:
    return fighter != null and s != null and fighter.data != null and fighter.fighter_id == s.fighter_id and s.character_id != &"" and fighter.data.id == s.character_id

static func restore(fighter: Fighter, s: FighterStateSnapshot) -> bool:
    if not is_compatible(fighter, s):
        if fighter != null and s != null and fighter.data != null and fighter.fighter_id == s.fighter_id and fighter.data.id != s.character_id:
            push_error("Snapshot character mismatch for P%d: snapshot=%s runtime=%s" % [fighter.fighter_id, String(s.character_id), String(fighter.data.id)])
        return false

    fighter.movement_motor.sim_position = s.sim_position
    fighter.movement_motor.velocity_units = s.velocity_units
    fighter.movement_motor.facing = -1 if s.facing < 0 else 1
    fighter.movement_motor.landed_this_frame = s.landed_this_frame

    fighter.combatant.hp = clampi(s.hp, 0, fighter.combatant.max_hp)
    fighter.combatant.hitstun_remaining = maxi(0, s.hitstun_remaining)
    fighter.combatant.blockstun_remaining = maxi(0, s.blockstun_remaining)
    fighter.combatant.hitstop_remaining = maxi(0, s.hitstop_remaining)
    fighter.combatant.knockback_velocity_x_units = s.knockback_velocity_x_units
    fighter.combatant.knockback_velocity_y_units = s.knockback_velocity_y_units
    fighter.combatant.is_ko = s.is_ko
    fighter.combatant.last_result_type = s.last_result_type
    fighter.meter.restore_value(s.meter_value)

    fighter.state_machine.root_state = s.root_state
    fighter.state_machine.state = s.state
    fighter.state_machine.previous_state = s.previous_state
    fighter.state_machine.guard_posture = s.guard_posture
    fighter.state_machine.air_attack_available = s.air_attack_available
    fighter.state_machine.landing_remaining = s.landing_remaining
    fighter.state_machine.dash_move_remaining = s.dash_move_remaining
    fighter.state_machine.dash_recovery_remaining = s.dash_recovery_remaining
    fighter.state_machine.dash_elapsed_frames = maxi(0, s.dash_elapsed_frames)
    fighter.state_machine.throw_protection_remaining = maxi(0, s.throw_protection_remaining)
    fighter.state_machine.thrown_remaining = s.thrown_remaining
    fighter.state_machine.knockdown_remaining = s.knockdown_remaining
    fighter.state_machine.getup_remaining = s.getup_remaining
    fighter.state_machine.pending_knockdown_frames = s.pending_knockdown_frames
    fighter.state_machine.pending_getup_frames = s.pending_getup_frames
    fighter.state_machine.throw_tech_pending = s.throw_tech_pending
    fighter.state_machine.jump_started_this_tick = s.jump_started_this_tick
    fighter.state_machine.jump_buffer_expiry_frame = s.jump_buffer_expiry_frame
    fighter.state_machine.charge_frames = maxi(0, s.charge_frames)
    fighter.state_machine.charge_entry_move_id = s.charge_entry_move_id
    fighter.state_machine.charge_locked_facing = -1 if s.charge_locked_facing < 0 else 1
    fighter.state_machine.charge_early_release_requested = s.charge_early_release_requested
    if fighter.state_machine.state == FighterStateMachine.State.CHARGE:
        var entry_move := fighter.move_registry.get_move(fighter.state_machine.charge_entry_move_id)
        if entry_move == null or entry_move.charge_special_data == null or not entry_move.charge_special_data.is_valid() or fighter.state_machine.charge_frames <= 0:
            return false
    elif fighter.state_machine.charge_frames != 0 or fighter.state_machine.charge_entry_move_id != &"" or fighter.state_machine.charge_early_release_requested:
        return false

    if not fighter.move_runner.restore_runtime(
        fighter.move_registry,
        s.current_move_id,
        s.move_frame,
        s.attack_instance_id,
        s.next_attack_instance_serial,
        s.move_connected_hit,
        s.move_connected_block,
        s.move_spawned_projectile_indices,
        s.move_activation_resource_values
    ):
        return false
    fighter.hitbox_owner.restore_contact_registry(s.tracked_attack_instance_id, s.contacted_defender_ids, s.contacted_hit_keys)
    if not fighter.resources.restore_values(s.resource_values): return false
    if not fighter.statuses.restore_state(s.status_states, s.next_status_application_serial): return false
    if not fighter.mode.restore_state(s.mode_state): return false
    if not fighter.mechanics_runtime.restore_state(s.mechanics_state): return false
    if not fighter.combo_scaling.restore_state(s.combo_state): return false
    fighter.sync_mechanics_from_mode()

    fighter.input_buffer.restore_snapshot(
        s.buffered_intent.to_intent() if s.buffered_intent != null else null,
        s.input_buffer_expiry_frame
    )

    var slots: Array[InputFrame] = []
    slots.resize(s.input_history_slots.size())
    for i in range(s.input_history_slots.size()):
        slots[i] = s.input_history_slots[i].to_frame() if s.input_history_slots[i] != null else null
    fighter.input_history.restore_slots(
        s.input_history_capacity,
        s.input_history_write_index,
        s.input_history_count,
        slots
    )

    # InputParser is derived from restored history + facing; no hidden command state is shared across restore.
    var latest := fighter.input_history.latest()
    if latest != null:
        fighter.input_parser.update(latest, fighter.movement_motor.facing, fighter.input_history)
    else:
        fighter.input_parser = InputParser.new()
    return true
