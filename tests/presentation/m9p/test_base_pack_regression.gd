class_name M9PBasePackRegressionTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    for asset_key: String in ["salad_cat", "magic_orange_cat"]:
        var path := "res://assets/characters/%s/animations/manifest.json" % asset_key
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        t.that(parsed is Dictionary, "%s BASE_FIGHTER manifest loads" % asset_key)
        if parsed is Dictionary:
            t.equal(int(parsed.get("manifest_version", 0)), 3, "%s base manifest upgraded to v3" % asset_key)
            t.equal(String(parsed.get("pack_type", "")), "BASE_FIGHTER", "%s remains BASE_FIGHTER" % asset_key)
            t.equal(int(parsed.get("frame_count", 0)), 250, "%s preserves 250-frame body contract" % asset_key)
            t.equal(String(parsed.get("mode_id", "x")), "", "%s base mode_id is empty" % asset_key)
    print("\nM9P BasePackRegression: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
