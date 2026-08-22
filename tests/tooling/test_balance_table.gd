class_name BalanceTableTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")

var t = ASSERT_HELPER.new()


func run_all() -> int:
    _test_formal_roster_rows_are_stable_and_complete()
    _test_filter_and_required_serializers()
    _test_effective_values_and_range_projection()
    print("\nBalanceTable tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed


func _test_formal_roster_rows_are_stable_and_complete() -> void:
    var result := BalanceTable.build_rows()
    t.equal(result["errors"], PackedStringArray(), "Formal roster balance projection has no validation errors")
    var rows: Array[Dictionary] = result["rows"]
    t.that(rows.size() >= RosterRegistry.count() * 7, "Every formal roster character contributes required move rows")
    var prior_key := ""
    var character_ids: Dictionary = {}
    var all_columns_present := true
    var stable_order := true
    for row in rows:
        for column in BalanceTable.COLUMNS:
            all_columns_present = all_columns_present and row.has(column)
        var stable_key := "%s/%s" % [row["character"], row["move"]]
        stable_order = stable_order and (prior_key.is_empty() or prior_key < stable_key)
        prior_key = stable_key
        character_ids[row["character"]] = true
    t.that(all_columns_present, "Every balance row contains every required column")
    t.that(stable_order, "Balance rows use deterministic stable-key order")
    t.equal(character_ids.size(), RosterRegistry.count(), "Balance export contains the complete formal roster")


func _test_filter_and_required_serializers() -> void:
    var result := BalanceTable.build_rows(&"magic_orange_cat")
    t.equal(result["errors"], PackedStringArray(), "Known stable character ID filters successfully")
    var rows: Array[Dictionary] = result["rows"]
    t.that(not rows.is_empty(), "Character filter returns move rows")
    for row in rows:
        t.equal(row["character"], "magic_orange_cat", "Character filter excludes other roster entries")
    var csv := BalanceTable.to_csv(rows)
    var markdown := BalanceTable.to_markdown(rows)
    t.that(csv.begins_with(",".join(BalanceTable.COLUMNS) + "\n"), "CSV uses the required deterministic header")
    t.that(markdown.begins_with("| " + " | ".join(BalanceTable.COLUMNS) + " |\n"), "Markdown uses the required deterministic header")
    t.that(csv.contains("magic_orange_cat,stand_light,"), "CSV includes stable character and move IDs")
    t.that(markdown.contains("| magic_orange_cat | stand_light |"), "Markdown includes stable character and move IDs")

    var missing := BalanceTable.build_rows(&"not_in_roster")
    t.that(not missing["errors"].is_empty(), "Unknown character stable ID fails closed")


func _test_effective_values_and_range_projection() -> void:
    var move := MoveData.new()
    move.id = &"test_move"
    move.damage = 10
    move.hitstun_frames = 4
    move.blockstun_frames = 2
    move.meter_cost = 25
    move.hitbox = BoxData.new()
    move.hitbox.offset = Vector2(20, 0)
    move.hitbox.size = Vector2(40, 20)
    var hit := MoveHitData.new()
    hit.damage = 30
    hit.hitstun_frames = 9
    hit.blockstun_frames = 6
    hit.hitbox = BoxData.new()
    hit.hitbox.offset = Vector2(45, 0)
    hit.hitbox.size = Vector2(30, 10)
    move.hits.append(hit)
    var character := CharacterData.new()
    character.id = &"test_character"
    var row := BalanceTable._row(character, move)
    t.equal(row["damage"], 30, "Multi-hit projection reports maximum per-hit damage")
    t.equal(row["hitstun"], 9, "Multi-hit projection reports maximum per-hit hitstun")
    t.equal(row["blockstun"], 6, "Multi-hit projection reports maximum per-hit blockstun")
    t.equal(row["meter"], 25, "Meter column reports meter cost")
    t.equal(row["range approximation"], 60, "Range approximation reports furthest authored forward hitbox edge")
