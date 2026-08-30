# Read-only join across a character package's gameplay, presentation, and art.
#
# One shared index feeds three consumers so CI failures, the CLI report, and the
# editor dock can never disagree:
#   CharacterValidator          -> hard errors / warnings
#   scripts/content_report.gd   -> markdown contributor report
#   addons/character_content_inspector -> editor dock
#
# Presentation-only: never referenced by BattleSimulation, BattleSnapshot,
# BattleStateHasher, or Replay gameplay truth. Loads resources but mutates
# nothing and instantiates no scene.
class_name ContentIndex
extends RefCounted

const SEVERITY_ERROR := "error"
const SEVERITY_WARNING := "warning"

# Animations an unbound move/state falls back to at runtime. Mirrors the
# defaults FighterPresentationResolver passes into CharacterPresentationData.
# MoveData.animation_id is NOT this path -- nothing reads that field.
const MOVE_FALLBACK_ANIMATION := PresentationAnimationIds.ATTACK_FALLBACK
const STATE_FALLBACK_ANIMATION := PresentationAnimationIds.IDLE

var characters: Array[Dictionary] = []

# allowlisted_unbound maps character_id -> Array[StringName] of move ids that are
# knowingly unbound. Callers load it from
# content/validation/unbound_moves_allowlist.json.
func build(manifests: Array[CharacterManifest], allowlisted_unbound: Dictionary = {}) -> void:
    characters.clear()
    for manifest: CharacterManifest in manifests:
        if manifest == null:
            continue
        characters.append(_index_character(manifest, allowlisted_unbound))

func issues(minimum_severity: String = SEVERITY_WARNING) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for entry: Dictionary in characters:
        for issue: Dictionary in entry["issues"]:
            if minimum_severity == SEVERITY_ERROR and issue["severity"] != SEVERITY_ERROR:
                continue
            out.append(issue)
    return out

func character(character_id: StringName) -> Dictionary:
    for entry: Dictionary in characters:
        if entry["character_id"] == character_id:
            return entry
    return {}

func _index_character(manifest: CharacterManifest, allowlisted_unbound: Dictionary) -> Dictionary:
    var character_id := manifest.id
    var entry: Dictionary = {
        "character_id": character_id,
        "display_name": manifest.display_name,
        "available": manifest.available,
        "animations": [],
        "animation_keys": {},
        "moves": [],
        "states": [],
        "modes": [],
        "issues": [],
    }

    var presentation := manifest.presentation_resource
    var gameplay := manifest.gameplay_resource
    if presentation == null:
        _add_issue(entry, SEVERITY_ERROR, "presentation.missing", "no presentation resource")
        return entry

    var base_keys := _animation_keys_from_scene(presentation.fighter_visual_scene)
    entry["animation_keys"] = base_keys
    entry["animations"] = _animation_details(presentation.fighter_visual_scene, base_keys)

    var allowlist: Dictionary = {}
    for move_id: Variant in allowlisted_unbound.get(String(character_id), []):
        allowlist[StringName(move_id)] = true

    _index_moves(entry, gameplay, presentation, base_keys, allowlist)
    _index_states(entry, presentation, base_keys)
    _index_modes(entry, presentation, base_keys)
    _index_orphans(entry, base_keys)
    _index_fallbacks(entry, base_keys)
    return entry

# V5: an unbound move/state resolves to a fallback key. If that key is not in
# SpriteFrames the sprite cannot play anything -- the frame is left on whatever
# was showing. Report it so "unbound" is never mistaken for "shows a generic
# animation".
func _index_fallbacks(entry: Dictionary, base_keys: Dictionary) -> void:
    entry["move_fallback_exists"] = base_keys.has(MOVE_FALLBACK_ANIMATION)
    entry["state_fallback_exists"] = base_keys.has(STATE_FALLBACK_ANIMATION)
    for fallback: StringName in [MOVE_FALLBACK_ANIMATION, STATE_FALLBACK_ANIMATION]:
        if base_keys.has(fallback):
            continue
        _add_issue(entry, SEVERITY_WARNING, "animation.fallback_missing",
            "fallback animation '%s' does not exist in SpriteFrames; anything unbound renders nothing" % String(fallback))

func _index_moves(
    entry: Dictionary,
    gameplay: CharacterData,
    presentation: CharacterPresentationData,
    base_keys: Dictionary,
    allowlist: Dictionary
) -> void:
    if gameplay == null or gameplay.move_set == null:
        return
    var grouped := _group_move_bindings(presentation)
    var move_rows: Array[Dictionary] = []
    for move: MoveData in gameplay.move_set.moves:
        if move == null:
            continue
        var bindings: Array = grouped.get(move.id, [])
        var row: Dictionary = {
            "move_id": move.id,
            "display_name": move.display_name,
            "animation_id": move.animation_id,
            "startup_frames": move.startup_frames,
            "active_frames": move.active_frames,
            "recovery_frames": move.recovery_frames,
            "damage": move.damage,
            "bindings": [],
            "bound": not bindings.is_empty(),
            "allowlisted": allowlist.has(move.id),
        }
        for binding: MovePresentationBinding in bindings:
            row["bindings"].append(_binding_row(binding, binding.animation_key, base_keys))
        move_rows.append(row)

        # V2: an unbound move resolves to MOVE_FALLBACK_ANIMATION, which may not
        # exist in this character's SpriteFrames at all.
        if bindings.is_empty():
            var consequence := "falls back to '%s'" % String(MOVE_FALLBACK_ANIMATION)
            if not base_keys.has(MOVE_FALLBACK_ANIMATION):
                consequence = "falls back to '%s', which this character does not have -- renders nothing" % String(MOVE_FALLBACK_ANIMATION)
            if allowlist.has(move.id):
                _add_issue(entry, SEVERITY_WARNING, "move.unbound_allowlisted",
                    "move '%s' has no presentation binding (allowlisted); %s" % [String(move.id), consequence])
            else:
                _add_issue(entry, SEVERITY_ERROR, "move.unbound",
                    "move '%s' has no presentation binding; %s" % [String(move.id), consequence])

        # V1a: every bound animation key must exist in the base SpriteFrames.
        for binding: MovePresentationBinding in bindings:
            if not base_keys.has(binding.animation_key):
                _add_issue(entry, SEVERITY_ERROR, "move.animation_missing",
                    "move '%s' binds animation '%s' which does not exist in SpriteFrames" % [String(move.id), String(binding.animation_key)])

        # V3: conditioned variants without an unconditional fallback must cover
        # the whole resource range, or some values silently fall back.
        _check_variant_coverage(entry, gameplay, "move", move.id, bindings)
    entry["moves"] = move_rows

func _index_states(entry: Dictionary, presentation: CharacterPresentationData, base_keys: Dictionary) -> void:
    var grouped: Dictionary = {}
    var order: Array[StringName] = []
    for binding: StatePresentationBinding in presentation.state_bindings:
        if binding == null:
            continue
        if not grouped.has(binding.state_key):
            grouped[binding.state_key] = []
            order.append(binding.state_key)
        (grouped[binding.state_key] as Array).append(binding)
    var state_rows: Array[Dictionary] = []
    for state_key: StringName in order:
        var bindings: Array = grouped[state_key]
        var row: Dictionary = {"state_key": state_key, "bindings": []}
        for binding: StatePresentationBinding in bindings:
            row["bindings"].append(_binding_row(binding, binding.animation_key, base_keys))
            if not base_keys.has(binding.animation_key):
                _add_issue(entry, SEVERITY_ERROR, "state.animation_missing",
                    "state '%s' binds animation '%s' which does not exist in SpriteFrames" % [String(state_key), String(binding.animation_key)])
        state_rows.append(row)
    entry["states"] = state_rows

func _index_modes(entry: Dictionary, presentation: CharacterPresentationData, base_keys: Dictionary) -> void:
    var mode_rows: Array[Dictionary] = []
    for binding: ModePresentationBinding in presentation.mode_bindings:
        if binding == null:
            continue
        var mode_keys := _animation_keys_from_scene(binding.fighter_visual_scene)
        var missing_required: Array[StringName] = []
        for required: StringName in binding.required_animations:
            if not mode_keys.has(required):
                missing_required.append(required)
                # V1b: a mode that lacks a declared required animation breaks on entry.
                _add_issue(entry, SEVERITY_ERROR, "mode.required_animation_missing",
                    "mode '%s' is missing required animation '%s'" % [String(binding.mode_id), String(required)])
        var missing_from_base: Array[StringName] = []
        for key: StringName in base_keys:
            if not mode_keys.has(key):
                missing_from_base.append(key)
        if not missing_from_base.is_empty():
            # V1c: partial mode packs are legal, but the gap is worth seeing.
            missing_from_base.sort()
            _add_issue(entry, SEVERITY_WARNING, "mode.partial_pack",
                "mode '%s' pack covers %d/%d base animations" % [String(binding.mode_id), mode_keys.size(), base_keys.size()])
        mode_rows.append({
            "mode_id": binding.mode_id,
            "animation_count": mode_keys.size(),
            "missing_required": missing_required,
            "missing_from_base": missing_from_base,
            "pack_manifest_path": binding.pack_manifest_path,
        })
    entry["modes"] = mode_rows

func _index_orphans(entry: Dictionary, base_keys: Dictionary) -> void:
    var used: Dictionary = {}
    for row: Dictionary in entry["moves"]:
        for binding_row: Dictionary in row["bindings"]:
            used[binding_row["animation_key"]] = true
    for row: Dictionary in entry["states"]:
        for binding_row: Dictionary in row["bindings"]:
            used[binding_row["animation_key"]] = true
    var orphans: Array[StringName] = []
    for key: StringName in base_keys:
        if not used.has(key):
            orphans.append(key)
    orphans.sort()
    for animation_row: Dictionary in entry["animations"]:
        animation_row["referenced"] = used.has(animation_row["animation_key"])
    if not orphans.is_empty():
        # V4: built art nothing references. Never blocks CI; art routinely lands
        # ahead of the gameplay data that will use it.
        _add_issue(entry, SEVERITY_WARNING, "animation.orphan",
            "%d built animation(s) referenced by no binding: %s" % [orphans.size(), _preview(orphans)])

func _check_variant_coverage(
    entry: Dictionary,
    gameplay: CharacterData,
    binding_kind: String,
    key: StringName,
    bindings: Array
) -> void:
    var conditioned: Array[Dictionary] = []
    for binding: Variant in bindings:
        var condition := _variant_condition(binding)
        if condition.is_empty():
            return  # An unconditional binding covers every uncovered value.
        conditioned.append(condition)
    if conditioned.is_empty():
        return
    var resource_id: StringName = conditioned[0]["resource_id"]
    var resource_data := _resource_data(gameplay, resource_id)
    if resource_data == null:
        _add_issue(entry, SEVERITY_ERROR, "%s.unknown_resource" % binding_kind,
            "%s '%s' conditions on unknown resource '%s'" % [binding_kind, String(key), String(resource_id)])
        return
    var covered: Dictionary = {}
    for condition: Dictionary in conditioned:
        for value in range(condition["min"], int(condition["max"]) + 1):
            covered[value] = true
    var gaps: Array[int] = []
    for value in range(resource_data.min_value, resource_data.max_value + 1):
        if not covered.has(value):
            gaps.append(value)
    if not gaps.is_empty():
        _add_issue(entry, SEVERITY_ERROR, "%s.variant_gap" % binding_kind,
            "%s '%s' has no binding for %s=%s and no unconditional fallback" % [binding_kind, String(key), String(resource_id), str(gaps)])

func _resource_data(gameplay: CharacterData, resource_id: StringName) -> FighterResourceData:
    if gameplay == null or gameplay.mechanics == null:
        return null
    for resource_data: FighterResourceData in gameplay.mechanics.resources:
        if resource_data != null and resource_data.resource_id == resource_id:
            return resource_data
    return null

func _group_move_bindings(presentation: CharacterPresentationData) -> Dictionary:
    var grouped: Dictionary = {}
    for binding: MovePresentationBinding in presentation.move_bindings:
        if binding == null:
            continue
        if not grouped.has(binding.move_id):
            grouped[binding.move_id] = []
        (grouped[binding.move_id] as Array).append(binding)
    return grouped

func _binding_row(binding: Object, animation_key: StringName, base_keys: Dictionary) -> Dictionary:
    var condition := _variant_condition(binding)
    return {
        "animation_key": animation_key,
        "resource_id": condition.get("resource_id", &""),
        "resource_min_value": condition.get("min", 0),
        "resource_max_value": condition.get("max", 0),
        "exists": base_keys.has(animation_key),
    }

# Resource-conditioned bindings (Courage-style variants) are a newer presentation
# schema than some packages carry. Read the fields through Object.get so one
# index serves bindings with and without them instead of crashing on the older
# shape.
func _variant_condition(binding: Object) -> Dictionary:
    if binding == null:
        return {}
    var resource_id: Variant = binding.get("resource_id")
    if resource_id == null or String(resource_id) == "":
        return {}
    var minimum: Variant = binding.get("resource_min_value")
    var maximum: Variant = binding.get("resource_max_value")
    return {
        "resource_id": StringName(resource_id),
        "min": int(minimum) if minimum != null else 0,
        "max": int(maximum) if maximum != null else 0,
    }

# SpriteFrames is the runtime truth for which animations can play. Read it from
# the packed scene state so nothing is instantiated and no _ready runs.
func _animation_keys_from_scene(scene: PackedScene) -> Dictionary:
    var keys: Dictionary = {}
    var sprite_frames := _sprite_frames_from_scene(scene)
    if sprite_frames == null:
        return keys
    for name: StringName in sprite_frames.get_animation_names():
        keys[name] = true
    return keys

func _sprite_frames_from_scene(scene: PackedScene) -> SpriteFrames:
    if scene == null:
        return null
    var state := scene.get_state()
    for node_index in range(state.get_node_count()):
        for property_index in range(state.get_node_property_count(node_index)):
            if state.get_node_property_name(node_index, property_index) != &"sprite_frames":
                continue
            var value: Variant = state.get_node_property_value(node_index, property_index)
            if value is SpriteFrames:
                return value as SpriteFrames
    return null

# fps / loop / frame paths come from the build manifest, which the art pipeline
# writes next to the SpriteFrames. Missing or stale manifests degrade to keys
# only rather than failing the index.
func _animation_details(scene: PackedScene, base_keys: Dictionary) -> Array[Dictionary]:
    var sprite_frames := _sprite_frames_from_scene(scene)
    var manifest := _manifest_from_scene(scene)
    var by_key: Dictionary = {}
    for animation: Variant in manifest.get("animations", []):
        by_key[StringName(animation.get("key", ""))] = animation
    var rows: Array[Dictionary] = []
    var sorted_keys: Array[StringName] = []
    for key: StringName in base_keys:
        sorted_keys.append(key)
    sorted_keys.sort()
    for key: StringName in sorted_keys:
        var animation: Dictionary = by_key.get(key, {})
        var frames: Array = animation.get("frames", [])
        rows.append({
            "animation_key": key,
            "frame_count": sprite_frames.get_frame_count(key) if sprite_frames != null else 0,
            "fps": float(animation.get("fps", sprite_frames.get_animation_speed(key) if sprite_frames != null else 0.0)),
            "loop": bool(animation.get("loop", sprite_frames.get_animation_loop(key) if sprite_frames != null else false)),
            "source_frames": frames,
            "referenced": false,
        })
    return rows

func _manifest_from_scene(scene: PackedScene) -> Dictionary:
    if scene == null:
        return {}
    var state := scene.get_state()
    var manifest_path := ""
    for node_index in range(state.get_node_count()):
        for property_index in range(state.get_node_property_count(node_index)):
            if state.get_node_property_name(node_index, property_index) == &"manifest_path":
                manifest_path = String(state.get_node_property_value(node_index, property_index))
                break
    if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
    return parsed if parsed is Dictionary else {}

func _add_issue(entry: Dictionary, severity: String, code: String, message: String) -> void:
    entry["issues"].append({
        "severity": severity,
        "code": code,
        "character_id": entry["character_id"],
        "message": message,
    })

func _preview(values: Array[StringName], limit: int = 5) -> String:
    var shown: Array[String] = []
    for index in range(min(limit, values.size())):
        shown.append(String(values[index]))
    if values.size() > limit:
        shown.append("... (+%d)" % (values.size() - limit))
    return ", ".join(shown)
