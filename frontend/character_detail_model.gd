# View state for one character's movelist.
#
# Resolves each move's animation through CharacterPresentationData.animation_for_move,
# the same call FighterPresentationResolver makes during a match, so the page shows
# what the game will really play rather than a separate idea of it.
#
# Frontend-only: reads catalog and presentation resources, never BattleSimulation,
# and defines no combat rule. Tooling joins such as ContentIndex stay out of the
# runtime; "no animation bound" is derived here from the runtime resolver itself.
class_name CharacterDetailModel
extends RefCounted

const HIT_LEVEL_NAMES: Array[String] = ["HIGH", "MID", "LOW"]

var _manifest: CharacterManifest = null
var _rows: Array[Dictionary] = []

func configure(manifest: CharacterManifest) -> bool:
    _manifest = null
    _rows.clear()
    if manifest == null or manifest.gameplay_resource == null:
        return false
    var move_set := manifest.gameplay_resource.move_set
    if move_set == null or manifest.presentation_resource == null:
        return false
    _manifest = manifest
    for move: MoveData in move_set.moves:
        if move != null:
            _rows.append(_build_row(move, manifest.presentation_resource))
    return true

func display_name() -> String:
    return _manifest.display_name if _manifest != null else ""

func character_id() -> StringName:
    return _manifest.id if _manifest != null else &""

func fighter_visual_scene() -> PackedScene:
    if _manifest == null or _manifest.presentation_resource == null:
        return null
    return _manifest.presentation_resource.fighter_visual_scene

func presentation() -> CharacterPresentationData:
    return _manifest.presentation_resource if _manifest != null else null

func move_count() -> int:
    return _rows.size()

func move_row(index: int) -> Dictionary:
    if index < 0 or index >= _rows.size():
        return {}
    return _rows[index]

func _build_row(move: MoveData, presentation_data: CharacterPresentationData) -> Dictionary:
    # An empty fallback makes the resolver report "nothing bound" instead of
    # quietly substituting ATTACK_FALLBACK, which is the distinction the page
    # needs in order to label the move honestly.
    var bound_key := presentation_data.animation_for_move(move.id, &"")
    var has_animation := bound_key != &""
    return {
        "move_id": move.id,
        "display_name": move.display_name if move.display_name.strip_edges() != "" else String(move.id),
        "animation_key": bound_key,
        "playback_key": bound_key if has_animation else PresentationAnimationIds.ATTACK_FALLBACK,
        "has_animation": has_animation,
        "startup_frames": move.startup_frames,
        "active_frames": move.active_frames,
        "recovery_frames": move.recovery_frames,
        "total_frames": move.total_frames(),
        "damage": move.damage,
        "hit_level": _hit_level_name(move.hit_level),
    }

func _hit_level_name(hit_level: int) -> String:
    if hit_level < 0 or hit_level >= HIT_LEVEL_NAMES.size():
        return "MID"
    return HIT_LEVEL_NAMES[hit_level]
