class_name CharacterDetailModelTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const SALAD_CAT := "res://content/characters/salad_cat/character_manifest.tres"
const MAGIC_ORANGE_CAT := "res://content/characters/magic_orange_cat/character_manifest.tres"

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_configure_reports_roster_identity()
    _test_every_move_is_listed_with_frame_data()
    _test_bound_move_resolves_its_own_animation()
    _test_unbound_move_is_flagged_but_still_playable()
    _test_configure_rejects_incomplete_manifests()
    print("\nCharacterDetailModel tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_configure_reports_roster_identity() -> void:
    var model := _model(SALAD_CAT)
    t.equal(model.display_name(), (load(SALAD_CAT) as CharacterManifest).display_name,
        "Detail model reports the manifest display name")

func _test_every_move_is_listed_with_frame_data() -> void:
    var manifest := load(SALAD_CAT) as CharacterManifest
    var model := _model(SALAD_CAT)
    t.equal(model.move_count(), manifest.gameplay_resource.move_set.moves.size(),
        "Detail model lists every move in the move set")
    var row := _row_for(model, &"stand_heavy")
    t.equal(row["startup_frames"], 10, "Detail row carries startup frames")
    t.equal(row["active_frames"], 4, "Detail row carries active frames")
    t.equal(row["recovery_frames"], 19, "Detail row carries recovery frames")
    t.equal(row["total_frames"], 33, "Detail row carries total frames")
    t.equal(row["damage"], 82, "Detail row carries damage")

func _test_bound_move_resolves_its_own_animation() -> void:
    var row := _row_for(_model(SALAD_CAT), &"stand_heavy")
    t.that(row["has_animation"], "A bound move reports a bound animation")
    t.equal(row["animation_key"], &"stand_heavy", "A bound move resolves its own animation key")
    t.equal(row["playback_key"], &"stand_heavy", "A bound move plays its own animation")

# salad_wave_l1 has damage and hitboxes but no presentation binding, so the
# runtime resolves it to ATTACK_FALLBACK. The page must be able to say so rather
# than present the fallback as the move's real animation.
func _test_unbound_move_is_flagged_but_still_playable() -> void:
    var row := _row_for(_model(SALAD_CAT), &"salad_wave_l1")
    t.that(not row["has_animation"], "An unbound move reports no bound animation")
    t.equal(row["animation_key"], &"", "An unbound move exposes no animation key")
    t.equal(row["playback_key"], PresentationAnimationIds.ATTACK_FALLBACK,
        "An unbound move still offers the runtime fallback for playback")

    var magic := _row_for(_model(MAGIC_ORANGE_CAT), &"magic_circle_l1")
    t.that(not magic["has_animation"], "The same holds for the other Golden Pair charge tiers")

func _test_configure_rejects_incomplete_manifests() -> void:
    var model := CharacterDetailModel.new()
    t.that(not model.configure(null), "Detail model rejects a null manifest")
    t.equal(model.move_count(), 0, "A rejected manifest leaves no rows")

    var manifest := CharacterManifest.new()
    manifest.id = &"no_resources"
    t.that(not model.configure(manifest), "Detail model rejects a manifest with no gameplay resource")

# --- helpers -----------------------------------------------------------------

func _model(path: String) -> CharacterDetailModel:
    var model := CharacterDetailModel.new()
    model.configure(load(path) as CharacterManifest)
    return model

func _row_for(model: CharacterDetailModel, move_id: StringName) -> Dictionary:
    for index in range(model.move_count()):
        var row: Dictionary = model.move_row(index)
        if row["move_id"] == move_id:
            return row
    return {}
