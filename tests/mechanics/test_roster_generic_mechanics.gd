# Generic mechanics API regression coverage independent of concrete character branches.
class_name RosterGenericMechanicsTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_multi_hit_contact_keys()
    _test_status_resource_mode_primitives()
    _test_temporary_entity_primitives()
    _test_rules_versions()
    print("\nRoster Generic Mechanics tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_multi_hit_contact_keys() -> void:
    var owner := HitboxOwner.new()
    owner.begin_attack_instance(41)
    t.that(owner.can_hit_defender(41, 2, 0), "Hit 0 starts contactable")
    owner.record_hit(41, 2, 0)
    t.that(not owner.can_hit_defender(41, 2, 0), "Same AttackInstance+HitID+Defender is deduplicated")
    t.that(owner.can_hit_defender(41, 2, 1), "Different HitID remains contactable in same AttackInstance")

func _test_status_resource_mode_primitives() -> void:
    var pink := load("res://data/characters/pink_star.tres") as CharacterData
    var fighter := Fighter.new()
    fighter.configure(1, pink, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS, BattleSimulation.GROUND_Y_UNITS)
    t.equal(fighter.resources.get_value(&"face_actions"), 0, "Custom resource initializes from Resource data")
    t.that(fighter.resources.set_value(&"face_actions", 5), "Custom resource accepts bounded set")
    t.equal(fighter.resources.get_value(&"face_actions"), 5, "Custom resource stores primitive value")
    t.that(fighter.mode.enter(&"true_face", 0), "Mode enters through generic definition registry")
    t.equal(fighter.mode.resolve_move_id(MoveIds.STAND_HEAVY), &"pink_true_heavy", "Mode override resolves canonical Heavy generically")

func _test_temporary_entity_primitives() -> void:
    var system := TemporaryEntitySystem.new()
    system.reset_for_new_match()
    t.equal(system.next_instance_serial, 1, "Temporary entity serial starts deterministically")
    t.equal(system.capture_state().size(), 0, "Empty temporary entity state captures canonically")

func _test_rules_versions() -> void:
    t.equal(BattleStateSnapshot.VERSION, 8, "Authoritative snapshot schema is v8")
    t.equal(ReplayFormat.SCHEMA_VERSION, 1, "Replay payload schema remains input-only v1")
    t.equal(ReplayFormat.COMBAT_RULES_VERSION, 4, "Combat rules compatibility is v4")
