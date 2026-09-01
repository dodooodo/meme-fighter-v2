class_name TempuraPenguinRosterTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
func run_all() -> int:
    var c := load("res://data/characters/tempura_penguin.tres") as CharacterData
    var r := MoveRegistry.new(); r.configure(c.move_set)
    var e: GameplayEffectData = r.get_move(MoveIds.ULTIMATE).on_start_effects[0]
    t.equal(e.summon.spawn_count, 9, "Penguin Ultimate spawns exactly nine summons")
    t.equal(e.summon.spawn_wave_size, 3, "Penguin Ultimate schedules three summons per wave")
    t.equal(e.summon.shared_group_target_lockout_frames, 12, "Penguin Ultimate uses a 12F shared victim lock")
    t.equal(e.summon.max_hits_per_owner_combo, 3, "Penguin Ultimate caps summon hits at three per combo")
    t.that(r.get_move(MoveIds.CROUCH_LOW).hurtbox_overrides.size() > 0, "Penguin slide uses low-profile hurtbox data")
    print("\nTempura Penguin roster tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
