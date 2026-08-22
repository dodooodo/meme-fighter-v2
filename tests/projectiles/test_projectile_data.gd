# Responsibility: M5 immutable projectile data/spawn descriptor validation and canonical behavior-slot proof.
class_name Milestone5ProjectileDataTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData
var zone: CharacterData
var shot: ProjectileData
var super_shot: ProjectileData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    shot = load("res://data/projectiles/zone_shot.tres") as ProjectileData
    super_shot = load("res://data/projectiles/zone_super_shot.tres") as ProjectileData
    _test_projectile_values()
    _test_spawn_descriptors()
    _test_same_special_id_different_behavior()
    print("\nM5 Projectile Data tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_projectile_values() -> void:
    t.equal(shot.id, &"zone_shot", "Normal projectile stable ID")
    t.equal(shot.velocity_x_units_per_tick, 800, "Zone shot integer velocity")
    t.equal(shot.lifetime_frames, 120, "Zone shot lifetime")
    t.equal(shot.damage, 80, "Zone shot damage")
    t.equal(shot.hitstun_frames, 16, "Zone shot hitstun")
    t.equal(shot.blockstun_frames, 12, "Zone shot blockstun")
    t.equal(shot.hitstop_attacker, 4, "Zone shot attacker hitstop")
    t.equal(shot.hitstop_defender, 4, "Zone shot defender hitstop")
    t.equal(shot.hit_level, MoveData.HitLevel.MID, "Zone shot is MID")
    t.equal(shot.knockback_x_units, 700, "Zone shot knockback X")
    t.equal(shot.knockback_y_units, 0, "Zone shot knockback Y")
    t.equal(shot.meter_gain_on_hit, 14, "Zone shot HIT meter")
    t.equal(shot.meter_gain_on_block, 6, "Zone shot BLOCK meter")
    t.equal(shot.hitbox_size, Vector2(64, 40), "Zone shot static box")
    t.that(shot.is_valid(), "Zone shot passes typed data validation")

    t.equal(super_shot.id, &"zone_super_shot", "Super projectile stable ID")
    t.equal(super_shot.velocity_x_units_per_tick, 1100, "Super projectile integer velocity")
    t.equal(super_shot.lifetime_frames, 120, "Super projectile lifetime")
    t.equal(super_shot.damage, 220, "Super projectile damage")
    t.equal(super_shot.hitstun_frames, 26, "Super projectile hitstun")
    t.equal(super_shot.blockstun_frames, 18, "Super projectile blockstun")
    t.equal(super_shot.hitstop_attacker, 8, "Super projectile attacker hitstop")
    t.equal(super_shot.hitstop_defender, 8, "Super projectile defender hitstop")
    t.equal(super_shot.hit_level, MoveData.HitLevel.MID, "Super projectile is MID")
    t.equal(super_shot.knockback_x_units, 1500, "Super projectile knockback X")
    t.equal(super_shot.knockback_y_units, -400, "Super projectile knockback Y")
    t.equal(super_shot.meter_gain_on_hit, 0, "Super projectile gives no HIT meter")
    t.equal(super_shot.meter_gain_on_block, 0, "Super projectile gives no BLOCK meter")
    t.equal(super_shot.hitbox_size, Vector2(96, 72), "Super projectile static box")
    t.that(super_shot.is_valid(), "Super projectile passes typed data validation")
    t.that(shot.id != super_shot.id, "ProjectileData IDs are unique")

func _test_spawn_descriptors() -> void:
    var special := _move(zone, MoveIds.SPECIAL_NEUTRAL)
    var ultimate := _move(zone, MoveIds.ULTIMATE)
    t.equal(special.projectile_spawns.size(), 1, "Zone Special has exactly one projectile descriptor")
    t.equal(special.projectile_spawns[0].spawn_frame, 15, "Zone Special spawns on F15")
    t.equal(special.projectile_spawns[0].spawn_offset_units, Vector2i(100, -70), "Zone Special spawn offset")
    t.equal(special.projectile_spawns[0].projectile_data, shot, "Zone Special references zone_shot")
    t.that(special.projectile_spawns[0].is_valid_for_move(special.total_frames()), "Zone Special descriptor validates inside move timeline")
    t.equal(ultimate.projectile_spawns.size(), 1, "Zone Ultimate has exactly one projectile descriptor")
    t.equal(ultimate.projectile_spawns[0].spawn_frame, 19, "Zone Ultimate spawns on F19")
    t.equal(ultimate.projectile_spawns[0].spawn_offset_units, Vector2i(110, -80), "Zone Ultimate spawn offset")
    t.equal(ultimate.projectile_spawns[0].projectile_data, super_shot, "Zone Ultimate references zone_super_shot")
    t.that(ultimate.projectile_spawns[0].is_valid_for_move(ultimate.total_frames()), "Zone Ultimate descriptor validates inside move timeline")

func _move(data: CharacterData, id: StringName) -> MoveData:
    for move: MoveData in data.move_set.moves:
        if move.id == id:
            return move
    return null

func _test_same_special_id_different_behavior() -> void:
    var generic_special := _move(generic, MoveIds.SPECIAL_NEUTRAL)
    var rush_special := _move(rush, MoveIds.SPECIAL_NEUTRAL)
    var zone_special := _move(zone, MoveIds.SPECIAL_NEUTRAL)
    t.that(generic_special.hitbox != null and generic_special.projectile_spawns.is_empty(), "Generic canonical Special remains body strike only")
    t.that(rush_special.hitbox != null and rush_special.projectile_spawns.is_empty(), "Rush canonical Special remains different body strike only")
    t.that(zone_special.hitbox == null and zone_special.projectile_spawns.size() == 1, "Zone canonical Special is data-defined projectile spawn with no body hitbox")
