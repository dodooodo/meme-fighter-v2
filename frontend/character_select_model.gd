# Read-only frontend projection of the authoritative playable roster.
# RosterRegistry decides who is playable; CharacterCatalog only contributes
# optional package metadata and may not replace the registry's active resources.
class_name CharacterSelectModel
extends RefCounted

var _entries: Array[Dictionary] = []

func load_builtin_roster() -> bool:
    var catalog := CharacterCatalog.new()
    catalog.discover_builtin()
    _entries.clear()
    var seen_ids: Dictionary = {}
    for roster_item: Dictionary in RosterRegistry.ENTRIES:
        var id := roster_item.get("id", &"") as StringName
        var character := roster_item.get("character", null) as CharacterData
        var presentation := roster_item.get("presentation", null) as CharacterPresentationData
        if id.is_empty() or seen_ids.has(id) or character == null or presentation == null:
            _entries.clear()
            return false
        if character.id != id or presentation.character_id != id:
            _entries.clear()
            return false
        seen_ids[id] = true
        var manifest := catalog.get_manifest(id)
        if manifest != null:
            if not manifest.available or manifest.gameplay_resource != character or manifest.presentation_resource != presentation:
                _entries.clear()
                return false
        _entries.append({
            "id": id,
            "display_name": String(roster_item.get("name", "")),
            "character": character,
            "presentation": presentation,
            "manifest": manifest,
            "source_type": "PACKAGE" if manifest != null else "LEGACY",
        })
    return _entries.size() == RosterRegistry.count()

func entries() -> Array[Dictionary]:
    return _entries.duplicate()

func entry(index: int) -> Dictionary:
    if index < 0 or index >= _entries.size():
        return {}
    return _entries[index]

func index_for_id(id: StringName) -> int:
    for index in range(_entries.size()):
        if _entries[index]["id"] == id:
            return index
    return -1

func count() -> int:
    return _entries.size()
