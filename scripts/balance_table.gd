# Responsibility: Read-only deterministic balance-table projection of authoritative CharacterData and MoveData.
# Owns: stable row keys, documented scalar/derived columns, CSV and Markdown serialization.
# Does NOT own: gameplay resource mutation, spreadsheet import, combat decisions, or runtime state.
# Dependencies: RosterRegistry, CharacterData, MoveData, MoveHitData, BoxData.
class_name BalanceTable
extends RefCounted

const COLUMNS: Array[String] = [
    "character",
    "move",
    "startup",
    "active",
    "recovery",
    "damage",
    "hitstun",
    "blockstun",
    "meter",
    "range approximation",
]


static func build_rows(character_filter: StringName = &"") -> Dictionary:
    var rows: Array[Dictionary] = []
    var errors := PackedStringArray()
    var stable_keys: Dictionary = {}
    var matched_character := false

    for index in range(RosterRegistry.count()):
        var entry := RosterRegistry.entry(index)
        var character := entry.get("character") as CharacterData
        if character == null:
            errors.append("roster entry %d has no CharacterData" % index)
            continue
        if not character_filter.is_empty() and character.id != character_filter:
            continue
        matched_character = true
        if character.id.is_empty():
            errors.append("roster entry %d has an empty character ID" % index)
            continue
        if character.move_set == null:
            errors.append("character %s has no MoveSetData" % String(character.id))
            continue
        for move_index in range(character.move_set.moves.size()):
            var move := character.move_set.moves[move_index]
            if move == null:
                errors.append("character %s move index %d is null" % [String(character.id), move_index])
                continue
            if move.id.is_empty():
                errors.append("character %s move index %d has an empty move ID" % [String(character.id), move_index])
                continue
            var stable_key := "%s/%s" % [String(character.id), String(move.id)]
            if stable_keys.has(stable_key):
                errors.append("duplicate balance stable key: %s" % stable_key)
                continue
            stable_keys[stable_key] = true
            rows.append(_row(character, move))

    if not character_filter.is_empty() and not matched_character:
        errors.append("unknown formal roster character: %s" % String(character_filter))
    rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_key := "%s/%s" % [a["character"], a["move"]]
        var b_key := "%s/%s" % [b["character"], b["move"]]
        return a_key < b_key
    )
    errors.sort()
    return {"rows": rows, "errors": errors}


static func to_csv(rows: Array[Dictionary]) -> String:
    var lines: Array[String] = [",".join(COLUMNS)]
    for row in rows:
        var values: Array[String] = []
        for column in COLUMNS:
            values.append(_csv_cell(str(row[column])))
        lines.append(",".join(values))
    return "\n".join(lines) + "\n"


static func to_markdown(rows: Array[Dictionary]) -> String:
    var lines: Array[String] = []
    lines.append("| " + " | ".join(COLUMNS) + " |")
    var separators: Array[String] = []
    separators.resize(COLUMNS.size())
    separators.fill("---")
    lines.append("| " + " | ".join(separators) + " |")
    for row in rows:
        var values: Array[String] = []
        for column in COLUMNS:
            values.append(_markdown_cell(str(row[column])))
        lines.append("| " + " | ".join(values) + " |")
    return "\n".join(lines) + "\n"


static func _row(character: CharacterData, move: MoveData) -> Dictionary:
    var maximum_damage := move.damage
    var maximum_hitstun := move.hitstun_frames
    var maximum_blockstun := move.blockstun_frames
    for hit: MoveHitData in move.hits:
        if hit == null:
            continue
        maximum_damage = maxi(maximum_damage, hit.damage)
        maximum_hitstun = maxi(maximum_hitstun, hit.hitstun_frames)
        maximum_blockstun = maxi(maximum_blockstun, hit.blockstun_frames)
    return {
        "character": String(character.id),
        "move": String(move.id),
        "startup": move.startup_frames,
        "active": move.active_frames,
        "recovery": move.recovery_frames,
        "damage": maximum_damage,
        "hitstun": maximum_hitstun,
        "blockstun": maximum_blockstun,
        "meter": move.meter_cost,
        "range approximation": _range_approximation(move),
    }


static func _range_approximation(move: MoveData) -> int:
    var forward_edge := 0.0
    forward_edge = maxf(forward_edge, _box_forward_edge(move.hitbox))
    forward_edge = maxf(forward_edge, _box_forward_edge(move.throw_box))
    for hit: MoveHitData in move.hits:
        if hit != null:
            forward_edge = maxf(forward_edge, _box_forward_edge(hit.hitbox))
    return ceili(forward_edge)


static func _box_forward_edge(box: BoxData) -> float:
    if box == null:
        return 0.0
    return maxf(0.0, box.offset.x + box.size.x * 0.5)


static func _csv_cell(value: String) -> String:
    if value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
        return "\"%s\"" % value.replace("\"", "\"\"")
    return value


static func _markdown_cell(value: String) -> String:
    return value.replace("\\", "\\\\").replace("|", "\\|").replace("\r", " ").replace("\n", " ")
