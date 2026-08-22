class_name CharacterValidatorTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const GOLDEN_PAIR_MANIFESTS: Array[String] = [
    "res://content/characters/magic_orange_cat/character_manifest.tres",
    "res://content/characters/salad_cat/character_manifest.tres",
]

var t = ASSERT_HELPER.new()
var validator := CharacterValidator.new()

func run_all() -> int:
    _test_golden_pair_is_valid()
    _test_manifest_and_identity_errors()
    _test_move_and_frame_errors()
    _test_null_and_empty_errors()
    _test_art_cancel_and_projectile_errors()
    _test_global_identity_errors()
    _test_error_order_is_stable()
    print("\nCharacterValidator tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_golden_pair_is_valid() -> void:
    var manifests: Array[CharacterManifest] = []
    for path: String in GOLDEN_PAIR_MANIFESTS:
        manifests.append(load(path) as CharacterManifest)
    var errors := validator.validate_manifests(manifests)
    t.equal(errors, PackedStringArray(), "Golden Pair packages pass all character validation")

func _test_manifest_and_identity_errors() -> void:
    var missing := _valid_manifest(&"missing_resource")
    missing.gameplay_resource = null
    t.that(_contains(validator.validate_manifest(missing), "gameplay_resource is required"), "Validator rejects missing gameplay references")

    var mismatch := _valid_manifest(&"identity_mismatch")
    mismatch.gameplay_resource.id = &"different_id"
    t.that(_contains(validator.validate_manifest(mismatch), "gameplay resource id mismatch"), "Validator rejects character identity mismatch")

func _test_move_and_frame_errors() -> void:
    var duplicate := _valid_manifest(&"duplicate_move")
    duplicate.gameplay_resource.move_set.moves.append(duplicate.gameplay_resource.move_set.moves[0])
    t.that(_contains(validator.validate_manifest(duplicate), "duplicate move id"), "Validator rejects duplicate move IDs")

    var required := _valid_manifest(&"required_move")
    required.gameplay_resource.move_set.moves.pop_back()
    t.that(_contains(validator.validate_manifest(required), "required move missing: ultimate"), "Validator rejects missing required moves")

    var frames := _valid_manifest(&"invalid_frames")
    frames.gameplay_resource.move_set.moves[0].startup_frames = -1
    t.that(_contains(validator.validate_manifest(frames), "invalid frame data"), "Validator rejects invalid frame data")

func _test_null_and_empty_errors() -> void:
    var empty := _valid_manifest(&"empty_moves")
    empty.gameplay_resource.move_set.moves.clear()
    t.that(_contains(validator.validate_manifest(empty), "move_set must contain MoveData"), "Validator rejects empty move arrays")

    var null_move := _valid_manifest(&"null_move")
    null_move.gameplay_resource.move_set.moves.append(null)
    t.that(_contains(validator.validate_manifest(null_move), "contains null MoveData"), "Validator rejects null move entries")

    var missing_presentation := _valid_manifest(&"missing_presentation")
    missing_presentation.presentation_resource = null
    t.that(_contains(validator.validate_manifest(missing_presentation), "presentation_resource is required"), "Validator rejects missing presentation references")

func _test_art_cancel_and_projectile_errors() -> void:
    var art := _valid_manifest(&"missing_art")
    art.presentation_resource.fighter_visual_scene = null
    t.that(_contains(validator.validate_manifest(art), "missing art binding"), "Validator rejects missing art bindings")

    var cancel := _valid_manifest(&"bad_cancel")
    var window := CancelWindowData.new()
    window.allowed_target_move_ids = [&"does_not_exist"]
    cancel.gameplay_resource.move_set.moves[0].cancel_windows.append(window)
    t.that(_contains(validator.validate_manifest(cancel), "impossible cancel target"), "Validator rejects impossible cancel targets")

    var cancel_range := _valid_manifest(&"bad_cancel_range")
    var long_window := CancelWindowData.new()
    long_window.start_frame = 3
    long_window.end_frame = 2
    long_window.allowed_target_move_ids = [&"stand_heavy"]
    cancel_range.gameplay_resource.move_set.moves[0].cancel_windows.append(long_window)
    t.that(_contains(validator.validate_manifest(cancel_range), "cancel window range"), "Validator rejects impossible cancel window ranges")

    var projectiles := _valid_manifest(&"duplicate_projectile")
    _add_projectile(projectiles.gameplay_resource.move_set.moves[0], &"shared_projectile")
    _add_projectile(projectiles.gameplay_resource.move_set.moves[1], &"shared_projectile")
    t.that(_contains(validator.validate_manifest(projectiles), "duplicate projectile id"), "Validator rejects duplicate projectile IDs")

    var bad_spawn := _valid_manifest(&"bad_spawn")
    _add_projectile(bad_spawn.gameplay_resource.move_set.moves[0], &"late_projectile", 99)
    t.that(_contains(validator.validate_manifest(bad_spawn), "invalid frame data for projectile spawn"), "Validator rejects invalid projectile spawn frames")

    var missing_binding := _valid_manifest(&"missing_move_binding")
    missing_binding.presentation_resource.move_bindings.pop_back()
    t.that(_contains(validator.validate_manifest(missing_binding), "missing art binding for move: ultimate"), "Validator rejects missing move art bindings")

func _test_global_identity_errors() -> void:
    var first := _valid_manifest(&"same_manifest")
    var second := _valid_manifest(&"same_manifest")
    second.content_pack_id = &"second_pack"
    var manifests: Array[CharacterManifest] = [first, second]
    t.that(_contains(validator.validate_manifests(manifests), "duplicate manifest id"), "Validator rejects duplicate manifest IDs")

    var pack_first := _valid_manifest(&"pack_first")
    var pack_second := _valid_manifest(&"pack_second")
    pack_second.content_pack_id = pack_first.content_pack_id
    manifests = [pack_first, pack_second]
    t.that(_contains(validator.validate_manifests(manifests), "duplicate content pack id"), "Validator rejects duplicate content-pack IDs")

    var projectile_first := _valid_manifest(&"projectile_first")
    var projectile_second := _valid_manifest(&"projectile_second")
    _add_projectile(projectile_first.gameplay_resource.move_set.moves[0], &"shared_global")
    _add_projectile(projectile_second.gameplay_resource.move_set.moves[0], &"shared_global")
    manifests = [projectile_first, projectile_second]
    t.that(_contains(validator.validate_manifests(manifests), "duplicate projectile id across packages"), "Validator rejects duplicate projectile IDs across packages")

func _test_error_order_is_stable() -> void:
    var invalid := _valid_manifest(&"stable_errors")
    invalid.gameplay_resource.move_set.moves.clear()
    t.equal(
        validator.validate_manifest(invalid),
        validator.validate_manifest(invalid),
        "Validator returns deterministic human-readable error ordering"
    )

func _valid_manifest(id: StringName) -> CharacterManifest:
    var move_set := MoveSetData.new()
    for move_id: StringName in CharacterValidator.REQUIRED_MOVE_IDS:
        var move := MoveData.new()
        move.id = move_id
        move.display_name = String(move_id)
        move.animation_id = move_id
        move.startup_frames = 1
        move.active_frames = 1
        move.recovery_frames = 1
        move_set.moves.append(move)

    var character := CharacterData.new()
    character.id = id
    character.display_name = String(id)
    character.pushbox = BoxData.new()
    character.hurtbox = BoxData.new()
    character.move_set = move_set

    var presentation := CharacterPresentationData.new()
    presentation.character_id = id
    presentation.display_name = String(id)
    presentation.fighter_visual_scene = PackedScene.new()
    for move_id: StringName in CharacterValidator.REQUIRED_MOVE_IDS:
        var binding := MovePresentationBinding.new()
        binding.move_id = move_id
        binding.animation_key = move_id
        presentation.move_bindings.append(binding)

    var manifest := CharacterManifest.new()
    manifest.id = id
    manifest.display_name = String(id)
    manifest.content_pack_id = StringName(String(id) + "_pack")
    manifest.gameplay_resource = character
    manifest.presentation_resource = presentation
    return manifest

func _add_projectile(move: MoveData, projectile_id: StringName, spawn_frame: int = 1) -> void:
    var projectile := ProjectileData.new()
    projectile.id = projectile_id
    var spawn := ProjectileSpawnData.new()
    spawn.spawn_frame = spawn_frame
    spawn.projectile_data = projectile
    move.projectile_spawns.append(spawn)

func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false
