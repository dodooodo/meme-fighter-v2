# Read-only validation for manifest-backed character packages.
class_name CharacterValidator
extends RefCounted

const UNBOUND_ALLOWLIST_PATH := "res://content/validation/unbound_moves_allowlist.json"

const REQUIRED_MOVE_IDS: Array[StringName] = [
    &"stand_light",
    &"stand_heavy",
    &"crouch_low",
    &"air_attack",
    &"ground_throw",
    &"special_neutral",
    &"ultimate",
]

func validate_manifest(manifest: CharacterManifest) -> PackedStringArray:
    var errors := PackedStringArray()
    if manifest == null:
        errors.append("manifest is required")
        return errors
    for error: String in manifest.validate():
        errors.append(error)
    var character := manifest.gameplay_resource
    var presentation := manifest.presentation_resource
    if character == null:
        return errors
    if character.pushbox == null:
        errors.append("missing gameplay resource: pushbox")
    if character.hurtbox == null:
        errors.append("missing gameplay resource: hurtbox")
    if character.move_set == null:
        errors.append("missing gameplay resource: move_set")
        return errors

    var moves_by_id: Dictionary = {}
    var projectile_ids: Dictionary = {}
    if character.move_set.moves.is_empty():
        errors.append("move_set must contain MoveData")
    for move: MoveData in character.move_set.moves:
        if move == null:
            errors.append("move_set contains null MoveData")
            continue
        if move.id == &"":
            errors.append("move id must be non-empty")
        elif moves_by_id.has(move.id):
            errors.append("duplicate move id: %s" % String(move.id))
        else:
            moves_by_id[move.id] = move
        _validate_frame_data(move, errors)
        _validate_projectiles(move, projectile_ids, errors)

    for required_id: StringName in REQUIRED_MOVE_IDS:
        if not moves_by_id.has(required_id):
            errors.append("required move missing: %s" % String(required_id))
    for move: MoveData in character.move_set.moves:
        if move != null:
            _validate_cancel_targets(move, moves_by_id, errors)
    _validate_art_bindings(presentation, manifest.id, moves_by_id, errors)
    return errors

func validate_manifests(manifests: Array[CharacterManifest]) -> PackedStringArray:
    var errors := PackedStringArray()
    _append_content_index_errors(manifests, errors)
    var manifest_ids: Dictionary = {}
    var content_pack_ids: Dictionary = {}
    var projectile_ids: Dictionary = {}
    for manifest: CharacterManifest in manifests:
        if manifest == null:
            errors.append("manifest is required")
            continue
        if manifest_ids.has(manifest.id):
            errors.append("duplicate manifest id: %s" % String(manifest.id))
        else:
            manifest_ids[manifest.id] = true
        if content_pack_ids.has(manifest.content_pack_id):
            errors.append("duplicate content pack id: %s" % String(manifest.content_pack_id))
        else:
            content_pack_ids[manifest.content_pack_id] = true
        for error: String in validate_manifest(manifest):
            errors.append("%s: %s" % [String(manifest.id), error])
        var character := manifest.gameplay_resource
        if character == null or character.move_set == null:
            continue
        for move: MoveData in character.move_set.moves:
            if move == null:
                continue
            for spawn: ProjectileSpawnData in move.projectile_spawns:
                if spawn == null or spawn.projectile_data == null:
                    continue
                var projectile_id := spawn.projectile_data.id
                if projectile_ids.has(projectile_id) and projectile_ids[projectile_id] != spawn.projectile_data:
                    errors.append("duplicate projectile id across packages: %s" % String(projectile_id))
                else:
                    projectile_ids[projectile_id] = spawn.projectile_data
    return errors

func _validate_frame_data(move: MoveData, errors: PackedStringArray) -> void:
    if move.startup_frames < 0 or move.active_frames < 0 or move.recovery_frames < 0:
        errors.append("invalid frame data for %s: negative phase" % String(move.id))
    if move.total_frames() <= 0:
        errors.append("invalid frame data for %s: total frames must be positive" % String(move.id))
    for window: CancelWindowData in move.cancel_windows:
        if window == null:
            errors.append("invalid frame data for %s: null cancel window" % String(move.id))
        elif window.start_frame < 1 or window.end_frame < window.start_frame:
            errors.append("invalid frame data for %s: cancel window range" % String(move.id))

func _validate_cancel_targets(move: MoveData, moves_by_id: Dictionary, errors: PackedStringArray) -> void:
    for window: CancelWindowData in move.cancel_windows:
        if window == null or window.target_kind != CancelWindowData.TargetKind.MOVE:
            continue
        if window.allowed_target_move_ids.is_empty():
            errors.append("impossible cancel target for %s: no move targets" % String(move.id))
        for target_id: StringName in window.allowed_target_move_ids:
            if not moves_by_id.has(target_id):
                errors.append("impossible cancel target for %s: %s" % [String(move.id), String(target_id)])

func _validate_projectiles(move: MoveData, projectile_ids: Dictionary, errors: PackedStringArray) -> void:
    for spawn: ProjectileSpawnData in move.projectile_spawns:
        if spawn == null or spawn.projectile_data == null:
            errors.append("missing projectile resource for move: %s" % String(move.id))
            continue
        if not spawn.is_valid_for_move(move.total_frames()):
            errors.append("invalid frame data for projectile spawn: %s" % String(move.id))
        var projectile_id := spawn.projectile_data.id
        if projectile_id == &"":
            errors.append("projectile id must be non-empty for move: %s" % String(move.id))
        elif projectile_ids.has(projectile_id) and projectile_ids[projectile_id] != spawn.projectile_data:
            errors.append("duplicate projectile id: %s" % String(projectile_id))
        else:
            projectile_ids[projectile_id] = spawn.projectile_data

func _validate_art_bindings(
    presentation: CharacterPresentationData,
    character_id: StringName,
    moves_by_id: Dictionary,
    errors: PackedStringArray
) -> void:
    if presentation == null:
        return
    for error: String in presentation.validate(character_id):
        errors.append(error)
    if presentation.fighter_visual_scene == null:
        errors.append("missing art binding: fighter_visual_scene")
    var bound_moves: Dictionary = {}
    for binding: MovePresentationBinding in presentation.move_bindings:
        if binding != null:
            bound_moves[binding.move_id] = true
    for required_id: StringName in REQUIRED_MOVE_IDS:
        if moves_by_id.has(required_id) and not bound_moves.has(required_id):
            errors.append("missing art binding for move: %s" % String(required_id))
    var sorted_move_ids: Array[StringName] = []
    for move_id: StringName in moves_by_id:
        sorted_move_ids.append(move_id)
    sorted_move_ids.sort()
    for move_id: StringName in sorted_move_ids:
        var move := moves_by_id[move_id] as MoveData
        if move != null and move.animation_id == &"":
            errors.append("missing art binding for move animation: %s" % String(move_id))

# Joins gameplay, presentation, and built art so that a binding pointing at a
# non-existent animation, or a move with no binding at all, fails CI instead of
# breaking silently in the running game. Warnings are surfaced by
# scripts/content_report.gd and the editor dock, not here.
func _append_content_index_errors(manifests: Array[CharacterManifest], errors: PackedStringArray) -> void:
    var index := ContentIndex.new()
    index.build(manifests, load_unbound_allowlist())
    for issue: Dictionary in index.issues(ContentIndex.SEVERITY_ERROR):
        errors.append("%s: %s" % [String(issue["character_id"]), issue["message"]])

static func load_unbound_allowlist(path: String = UNBOUND_ALLOWLIST_PATH) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        return {}
    var out: Dictionary = {}
    for character_id: Variant in (parsed as Dictionary).get("allowlist", {}):
        var move_ids: Array[StringName] = []
        for entry: Variant in (parsed as Dictionary)["allowlist"][character_id]:
            if entry is Dictionary and (entry as Dictionary).has("move_id"):
                move_ids.append(StringName((entry as Dictionary)["move_id"]))
        out[String(character_id)] = move_ids
    return out
