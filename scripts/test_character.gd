extends SceneTree

const PACKAGE_ROOT := "res://content/characters"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var arguments := OS.get_cmdline_user_args()
    if arguments.size() != 1:
        push_error("Usage: ./scripts/test_character.sh <character_id>")
        quit(64)
        return
    var character_id := StringName(arguments[0])
    if String(character_id).begins_with("_"):
        push_error("Reserved character package ID: " + String(character_id))
        quit(2)
        return
    var manifest_path := "%s/%s/character_manifest.tres" % [PACKAGE_ROOT, String(character_id)]
    if not ResourceLoader.exists(manifest_path):
        push_error("Unknown packaged character: " + String(character_id))
        quit(2)
        return
    var manifest := load(manifest_path) as CharacterManifest
    var manifests: Array[CharacterManifest] = [manifest]
    var validation_errors := CharacterValidator.new().validate_manifests(manifests)
    if not validation_errors.is_empty():
        for error: String in validation_errors:
            push_error("Character validation: " + error)
        quit(1)
        return
    var suite_path := "res://tests/characters/roster/test_%s.gd" % String(character_id)
    if not ResourceLoader.exists(suite_path):
        push_error("Packaged character has no focused test suite: " + String(character_id))
        quit(2)
        return
    var suite_script := load(suite_path) as Script
    var suite: RefCounted = suite_script.new()
    var failures := int(suite.call("run_all"))
    if failures == 0:
        print("Character test PASS: " + String(character_id))
    quit(failures)
