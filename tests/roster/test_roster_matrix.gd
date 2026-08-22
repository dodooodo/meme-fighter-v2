# Formal roster integrity + 14x14 deterministic configuration smoke test.
class_name FormalRosterMatrixTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_roster_resources()
    _test_pairwise_smoke()
    print("\nFormal Roster Matrix tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_roster_resources() -> void:
    t.equal(RosterRegistry.count(), 14, "Formal roster contains exactly 14 selectable characters")
    var ids: Dictionary = {}
    for index in range(RosterRegistry.count()):
        var entry := RosterRegistry.entry(index)
        var character := entry["character"] as CharacterData
        var presentation := entry["presentation"] as CharacterPresentationData
        t.that(character != null, "Roster character %d loads" % index)
        t.that(presentation != null, "Roster presentation %d loads" % index)
        if character == null or presentation == null:
            continue
        t.that(not ids.has(character.id), "Roster character ID %s is unique" % String(character.id))
        ids[character.id] = true
        t.equal(presentation.character_id, character.id, "%s presentation ID matches gameplay ID" % String(character.id))
        var registry := MoveRegistry.new()
        t.that(registry.configure(character.move_set), "%s MoveSet validates" % String(character.id))
        for move_id in [MoveIds.STAND_LIGHT, MoveIds.STAND_HEAVY, MoveIds.CROUCH_LOW, MoveIds.AIR_ATTACK, MoveIds.GROUND_THROW, MoveIds.SPECIAL_NEUTRAL, MoveIds.ULTIMATE]:
            t.that(registry.has_move(move_id), "%s owns canonical move %s" % [String(character.id), String(move_id)])

func _test_pairwise_smoke() -> void:
    var cases := 0
    for a_index in range(RosterRegistry.count()):
        for b_index in range(RosterRegistry.count()):
            var a := RosterRegistry.entry(a_index)["character"] as CharacterData
            var b := RosterRegistry.entry(b_index)["character"] as CharacterData
            var battle := BattleSimulation.new()
            battle.configure(a, b, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(78000, BattleSimulation.GROUND_Y_UNITS))
            battle.simulate_frame(InputFrame.neutral(1), InputFrame.neutral(1))
            battle.simulate_frame(InputFrame.neutral(2), InputFrame.neutral(2))
            t.that(battle.fighter_a.data.id == a.id and battle.fighter_b.data.id == b.id, "Pairwise smoke %s vs %s configures" % [String(a.id), String(b.id)])
            cases += 1
    t.equal(cases, 196, "14x14 pairwise smoke covers 196 matchups")
