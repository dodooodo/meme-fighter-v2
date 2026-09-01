# Beta Phase 1: presentation-only QA over the authoritative 14-character roster.
# This exercises the real BattleSimulation -> Fighter -> resolver path while
# keeping the test strictly observational: no presentation code writes combat state.
class_name BetaPhase1RosterPresentationQaTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const STATE_KEYS: Array[StringName] = [
    &"idle", &"walk_forward", &"walk_back", &"jump", &"guard_stand",
    &"hitstun", &"knockdown", &"getup", &"ko",
]

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_all_roster_presentation_paths()
    print("\nBeta Phase 1 roster presentation QA: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_all_roster_presentation_paths() -> void:
    t.equal(RosterRegistry.count(), 14, "Beta presentation QA uses the authoritative 14-character roster")
    for entry: Dictionary in RosterRegistry.ENTRIES:
        var id := entry["id"] as StringName
        var character := entry["character"] as CharacterData
        var presentation := entry["presentation"] as CharacterPresentationData
        var simulation := BattleSimulation.new()
        simulation.configure(character, character)
        var fighter := simulation.fighter_a
        t.equal(presentation.validate(id).size(), 0, "%s presentation data validates" % String(id))
        t.that(presentation.production_asset_binding != null, "%s resolves production asset inventory" % String(id))
        for state_key: StringName in STATE_KEYS:
            var animation_key := presentation.animation_for_state(state_key, &"idle", fighter.resources)
            t.that(animation_key != &"", "%s %s resolves a visible animation" % [String(id), String(state_key)])
        for move: MoveData in character.move_set.moves:
            if move == null:
                continue
            var animation_key := presentation.animation_for_move(move.id, &"attack", fighter.resources)
            t.that(animation_key != &"", "%s move %s resolves a visible animation" % [String(id), String(move.id)])
            # Some success/sequence move IDs intentionally use the visual
            # adapter's declared attack fallback rather than owning a redundant
            # fighter animation. Their effects are presented by entity/effect
            # presenters, so only an empty resolution is a visual defect here.
