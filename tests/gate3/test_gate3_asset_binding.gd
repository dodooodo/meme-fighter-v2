# Gate 3 production binding runtime contract tests. Presentation-only: never drives combat timing/collision.
class_name Gate3AssetBindingTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_all_roster_catalogs()
    _test_pink_alias()
    _test_fighter_anchor_and_no_red()
    _test_approved_yellow_fallbacks()
    print("\nGate 3 Asset Binding tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_all_roster_catalogs() -> void:
    t.equal(RosterRegistry.count(), 14, "Production binding test uses formal 14-character roster")
    for item: Dictionary in RosterRegistry.ENTRIES:
        var character_id := StringName(item["id"])
        var path := "res://presentation/resources/production_asset_bindings/%s.tres" % String(character_id)
        t.that(ResourceLoader.exists(path), "Production binding catalog exists: %s" % String(character_id))
        var catalog := load(path) as ProductionCharacterAssetBinding
        t.that(catalog != null, "Production binding catalog loads: %s" % String(character_id))
        if catalog == null:
            continue
        t.equal(catalog.character_id, character_id, "Catalog identity matches active roster: %s" % String(character_id))
        t.that(catalog.validate().is_empty(), "Inventory-backed frame references validate: %s" % String(character_id))
        t.that(catalog.rebuild_cache(), "Production binding cache builds: %s" % String(character_id))
        t.that(not catalog.bindings.is_empty(), "Catalog has production bindings: %s" % String(character_id))

func _test_pink_alias() -> void:
    var catalog := load("res://presentation/resources/production_asset_bindings/pink_star.tres") as ProductionCharacterAssetBinding
    t.that(catalog != null, "Pink production catalog loads")
    if catalog != null:
        t.equal(catalog.character_id, &"pink_star", "Pink canonical CharacterID remains pink_star")
        t.equal(catalog.display_name, "粉紅星星", "Pink canonical display name remains 粉紅星星")
        t.equal(catalog.asset_folder, "粉藍星星", "Pink production alias resolves to 粉藍星星")
    for item: Dictionary in RosterRegistry.ENTRIES:
        t.that(StringName(item["id"]) != &"blue_star", "No fifteenth blue_star roster entry exists")

func _test_fighter_anchor_and_no_red() -> void:
    for item: Dictionary in RosterRegistry.ENTRIES:
        var catalog := load("res://presentation/resources/production_asset_bindings/%s.tres" % String(item["id"])) as ProductionCharacterAssetBinding
        if catalog == null:
            continue
        var counts := catalog.status_counts()
        t.equal(int(counts.get("RED", 0)), 0, "No RED production binding: %s" % String(item["id"]))
        for binding: ProductionAnimationBinding in catalog.bindings:
            if binding == null:
                continue
            if binding.is_fighter_domain():
                t.equal(binding.anchor, &"FEET_CENTER", "Fighter binding uses FEET_CENTER: %s/%s" % [String(item["id"]), String(binding.animation_id)])
            for frame_path in binding.frame_paths:
                t.that(FileAccess.file_exists(frame_path), "Bound production frame exists: %s" % frame_path)

func _test_approved_yellow_fallbacks() -> void:
    var doge := load("res://presentation/resources/production_asset_bindings/doge.tres") as ProductionCharacterAssetBinding
    var blade := load("res://presentation/resources/production_asset_bindings/blade_shield.tres") as ProductionCharacterAssetBinding
    t.that(doge != null and doge.status_counts().get("YELLOW", 0) >= 1, "Doge charge key-pose hold is explicit approved YELLOW fallback")
    t.that(blade != null and blade.status_counts().get("YELLOW", 0) >= 1, "Blade Dual Special reuse is explicit approved YELLOW fallback")
    if blade != null:
        var dual_special := blade.binding_for_animation(&"special_neutral", &"dual_blade")
        t.that(dual_special != null and dual_special.status == &"YELLOW", "Blade Dual Special resolves approved presentation fallback without gameplay impact")
