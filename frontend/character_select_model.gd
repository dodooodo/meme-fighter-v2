# Read-only frontend projection of available built-in character packages.
class_name CharacterSelectModel
extends RefCounted

var _manifests: Array[CharacterManifest] = []

func load_builtin_roster() -> bool:
    var catalog := CharacterCatalog.new()
    if not catalog.discover_builtin():
        _manifests.clear()
        return false
    _manifests.clear()
    for manifest: CharacterManifest in catalog.list_manifests():
        if manifest.available:
            _manifests.append(manifest)
    return not _manifests.is_empty()

func manifests() -> Array[CharacterManifest]:
    return _manifests.duplicate()

func manifest(index: int) -> CharacterManifest:
    if index < 0 or index >= _manifests.size():
        return null
    return _manifests[index]

func count() -> int:
    return _manifests.size()
