class_name M9PPresentationGameplaySeparationTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var forbidden := ["ModePresentationBinding", "UltimatePresentationBinding", "EffectPresentationBinding", "AttachmentPresentationBinding", "Texture2D", "SpriteFrames"]
    var gameplay_paths := [
        "res://battle/battle_simulation.gd",
        "res://battle/combat/combat_resolver.gd",
        "res://fighter/fighter.gd",
        "res://fighter/moves/move_runner.gd",
        "res://battle/projectiles/projectile_system.gd",
        "res://battle/simulation/battle_state_hasher.gd",
        "res://battle/simulation/battle_state_snapshot.gd",
        "res://battle/replay/replay_data.gd",
    ]
    for path: String in gameplay_paths:
        var body := FileAccess.get_file_as_string(path)
        for token: String in forbidden:
            t.that(token not in body, "%s does not depend on Presentation type %s" % [path, token])
    print("\nM9P GameplaySeparation: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
