# Responsibility: M5 projectile snapshot behavior carried through M6 snapshot v6 identity, rehydration, mid-flight replay hash, multi-entity and spawn-once safety.
class_name Milestone5ProjectileSnapshotTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var generic: CharacterData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_schema_and_resource_free_projectile_fields()
    _test_midflight_roundtrip_and_replay_hash()
    _test_multiple_projectile_restore_and_serial()
    _test_facing_lifetime_restore_exact()
    _test_spawn_exactly_once_across_restore()
    _test_invalid_rehydration_identity_rejected()
    _test_duplicate_contact_state_survives_restore()
    _test_projectile_state_changes_hash()
    print("\nM5 Projectile Snapshot tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(ax: int = 30000, bx: int = 105000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(zone, generic, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _spawn(battle: BattleSimulation, id: StringName = MoveIds.SPECIAL_NEUTRAL) -> ProjectileRuntime:
    var move := battle.fighter_a.move_registry.get_move(id)
    return battle.projectile_system.spawn_from_descriptor(battle.fighter_a, id, 0, move.projectile_spawns[0])

func _tick(battle: BattleSimulation) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(InputFrame.neutral(f), InputFrame.neutral(f))

func _test_schema_and_resource_free_projectile_fields() -> void:
    var battle := _battle()
    var p := _spawn(battle)
    p.position_units = Vector2i(44444, 33333)
    p.remaining_lifetime_frames = 37
    var snapshot := battle.capture_state()
    t.equal(snapshot.version, BattleStateSnapshot.VERSION, "Current snapshot schema follows BattleStateSnapshot.VERSION")
    t.equal(snapshot.next_projectile_instance_serial, 2, "Snapshot captures next projectile serial")
    t.equal(snapshot.projectiles.size(), 1, "Snapshot captures active projectile array")
    var s := snapshot.projectiles[0]
    t.equal(s.instance_id, 1, "Projectile snapshot captures instance ID")
    t.equal(s.owner_fighter_id, 1, "Projectile snapshot captures stable owner participant")
    t.equal(s.source_move_id, MoveIds.SPECIAL_NEUTRAL, "Projectile snapshot captures source move ID")
    t.equal(s.spawn_index, 0, "Projectile snapshot captures spawn index")
    t.equal(s.projectile_id, &"zone_shot", "Projectile snapshot captures ProjectileData textual ID")
    t.equal(s.position_units, Vector2i(44444, 33333), "Projectile snapshot captures Vector2i position")
    t.equal(s.remaining_lifetime_frames, 37, "Projectile snapshot captures remaining lifetime")
    t.that(not _has_property(s, "projectile_data"), "ProjectileSnapshot exposes no Resource pointer field")

func _test_midflight_roundtrip_and_replay_hash() -> void:
    var battle := _battle()
    _spawn(battle)
    for _i in range(20):
        _tick(battle)
    var snapshot := battle.capture_state()
    var snapshot_hash := battle.state_signature()
    for _i in range(30):
        _tick(battle)
    var after_hash := battle.state_signature()
    t.that(battle.restore_state(snapshot), "Mid-flight projectile snapshot restores")
    t.equal(battle.state_signature(), snapshot_hash, "Restore returns exact mid-flight canonical hash")
    for _i in range(30):
        _tick(battle)
    t.equal(battle.state_signature(), after_hash, "Mid-flight restore + identical 30F re-sim produces same hash")

func _test_multiple_projectile_restore_and_serial() -> void:
    var battle := _battle()
    var a := _spawn(battle)
    var b := _spawn(battle)
    var c := _spawn(battle, MoveIds.ULTIMATE)
    a.position_units = Vector2i(31000, 52000)
    b.position_units = Vector2i(42000, 51000)
    c.position_units = Vector2i(53000, 50000)
    a.remaining_lifetime_frames = 91
    b.remaining_lifetime_frames = 73
    c.remaining_lifetime_frames = 55
    var snapshot := battle.capture_state()
    battle.projectile_system.clear_all()
    battle.projectile_system.next_projectile_instance_serial = 99
    t.that(battle.restore_state(snapshot), "Three-projectile snapshot restores")
    var active := battle.projectile_system.active_projectiles()
    t.equal(active.size(), 3, "All three projectiles restore")
    t.equal(active[0].instance_id, 1, "Restore preserves first instance ordering")
    t.equal(active[1].instance_id, 2, "Restore preserves second instance ordering")
    t.equal(active[2].instance_id, 3, "Restore preserves third instance ordering")
    t.equal(active[0].remaining_lifetime_frames, 91, "First projectile lifetime exact")
    t.equal(active[1].position_units, Vector2i(42000, 51000), "Second projectile position exact")
    t.equal(active[2].projectile_id, &"zone_super_shot", "Third projectile rehydrates correct super data")
    t.equal(battle.projectile_system.next_projectile_instance_serial, 4, "Next projectile serial restores exactly")

func _test_facing_lifetime_restore_exact() -> void:
    var battle := _battle()
    var p := _spawn(battle)
    p.facing = -1
    p.remaining_lifetime_frames = 37
    var snapshot := battle.capture_state()
    p.facing = 1
    p.remaining_lifetime_frames = 100
    battle.fighter_a.movement_motor.facing = 1
    t.that(battle.restore_state(snapshot), "Facing/lifetime snapshot restores")
    p = battle.projectile_system.active_projectiles()[0]
    t.equal(p.facing, -1, "Projectile restore never re-reads owner facing")
    t.equal(p.remaining_lifetime_frames, 37, "Projectile restore never resets lifetime to data default")

func _test_spawn_exactly_once_across_restore() -> void:
    var battle := _battle()
    battle.simulate_frame(InputFrame.with_special_press(1), InputFrame.neutral(1))
    battle.simulate_frame(InputFrame.new(2, 0, 0, 0, 0, InputFrame.InputButton.SPECIAL), InputFrame.neutral(2))
    battle.simulate_frame(InputFrame.new(3, 0, 0, 0, 0, InputFrame.InputButton.SPECIAL), InputFrame.neutral(3)) # minimum charge commits Lv1
    for _i in range(13):
        _tick(battle)
    var before_spawn := battle.capture_state()
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 1, "Original simulation spawns one projectile at F15")
    var spawned_hash := battle.state_signature()
    t.that(battle.restore_state(before_spawn), "Pre-spawn snapshot restores")
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 1, "Re-simulation spawns exactly one projectile")
    t.equal(battle.projectile_system.next_projectile_instance_serial, 2, "Re-simulation serial proves no duplicate spawn")
    t.equal(battle.state_signature(), spawned_hash, "Spawn-frame re-simulation reproduces exact hash")

func _test_invalid_rehydration_identity_rejected() -> void:
    var battle := _battle()
    _spawn(battle)
    var snapshot := battle.capture_state()
    snapshot.projectiles[0].projectile_id = &"wrong_projectile"
    var hash_before := battle.state_signature()
    t.that(not battle.restore_state(snapshot), "ProjectileData ID mismatch rejects restore loudly")
    t.equal(battle.state_signature(), hash_before, "Rejected projectile restore does not mutate live battle")

    var bad_spawn := battle.capture_state()
    bad_spawn.projectiles[0].spawn_index = 99
    t.that(not battle.restore_state(bad_spawn), "Invalid projectile spawn index rejects restore")

func _test_duplicate_contact_state_survives_restore() -> void:
    var battle := _battle(30000, 60000)
    var p := _spawn(battle)
    p.position_units = Vector2i(59000, BattleSimulation.GROUND_Y_UNITS - 7000)
    p.contacted_defender_ids = [battle.fighter_b.fighter_id]
    var snapshot := battle.capture_state()
    p.contacted_defender_ids.clear()
    t.that(battle.restore_state(snapshot), "Projectile duplicate-contact registry snapshot restores")
    var hp_before := battle.fighter_b.combatant.hp
    var meter_before := battle.fighter_a.meter.get_value()
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, hp_before, "Restored contacted-defender state prevents duplicate projectile damage")
    t.equal(battle.fighter_a.meter.get_value(), meter_before, "Restored contacted-defender state prevents duplicate projectile meter")

func _test_projectile_state_changes_hash() -> void:
    var battle := _battle()
    var no_projectile_hash := battle.state_signature()
    var p := _spawn(battle)
    var with_projectile_hash := battle.state_signature()
    t.that(no_projectile_hash != with_projectile_hash, "Active projectile presence participates in battle hash")
    p.position_units.x += 1
    var moved_hash := battle.state_signature()
    t.that(moved_hash != with_projectile_hash, "Projectile position participates in battle hash")
    battle.projectile_system.next_projectile_instance_serial += 1
    t.that(battle.state_signature() != moved_hash, "Next projectile serial participates in battle hash")

func _has_property(object: Object, property_name: String) -> bool:
    for property in object.get_property_list():
        if String(property.get("name", "")) == property_name:
            return true
    return false
