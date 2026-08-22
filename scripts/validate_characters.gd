extends SceneTree

const PACKAGE_ROOT := "res://content/characters"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var manifests: Array[CharacterManifest] = []
    var directories := DirAccess.get_directories_at(PACKAGE_ROOT)
    directories.sort()
    for directory: String in directories:
        if directory.begins_with("_"):
            continue
        var manifest_path := "%s/%s/character_manifest.tres" % [PACKAGE_ROOT, directory]
        if not ResourceLoader.exists(manifest_path):
            push_error("Character package is missing manifest: " + directory)
            quit(1)
            return
        var manifest := load(manifest_path) as CharacterManifest
        if manifest == null:
            push_error("Character package manifest failed to load: " + directory)
            quit(1)
            return
        manifests.append(manifest)
    var errors := CharacterValidator.new().validate_manifests(manifests)
    if not errors.is_empty():
        for error: String in errors:
            push_error("Character validation: " + error)
        quit(1)
        return
    print("Character validation PASS: %d package(s)" % manifests.size())
    quit(0)
