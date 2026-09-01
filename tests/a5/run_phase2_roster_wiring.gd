extends SceneTree

const SELECT_SCENE := preload("res://frontend/mode_select_scene.tscn")
const EXPECTED_IDS: Array[StringName] = [
    &"alien_meow", &"doge", &"ya_mouse", &"tempura_penguin", &"goblin_love",
    &"salad_cat", &"magic_orange_cat", &"blade_shield", &"pink_star",
    &"sauce_stubble_dog", &"scared_cat", &"ok_meow_boss", &"niu_lai", &"bao_la",
]
const PACKAGE_IDS: Array[StringName] = [&"doge", &"salad_cat", &"magic_orange_cat", &"niu_lai"]
const REPRESENTATIVE_IDS: Array[StringName] = [&"doge", &"alien_meow", &"pink_star", &"bao_la"]

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    root.size = Vector2i(1440, 900)
    await _verify_frontend_roster_and_both_slots()
    for id: StringName in REPRESENTATIVE_IDS:
        await _verify_frontend_to_battle(id)
    print("\nPhase 2 roster wiring runtime: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
    quit(0 if _failures == 0 else 1)


func _verify_frontend_roster_and_both_slots() -> void:
    var select := await _open_character_select()
    _check(select != null, "Real ModeSelectScene instantiates")
    if select == null:
        return
    _check(RosterRegistry.count() == 14, "RosterRegistry has exactly fourteen entries")
    _check(select.model.count() == 14, "CharacterSelectModel exposes all fourteen registry entries")
    _check(select.p1_select.item_count == 14, "P1 picker displays all fourteen entries")
    _check(select.p2_select.item_count == 14, "P2 picker displays all fourteen entries")
    var seen: Dictionary = {}
    for index in range(EXPECTED_IDS.size()):
        var expected_id := EXPECTED_IDS[index]
        var frontend_entry: Dictionary = select.model.entry(index)
        var roster_entry := RosterRegistry.entry(index)
        _check(frontend_entry.get("id", &"") == expected_id, "%s appears once in authored frontend order" % String(expected_id))
        _check(not seen.has(expected_id), "%s is not duplicated" % String(expected_id))
        seen[expected_id] = true
        _check(frontend_entry.get("character") == roster_entry.get("character"), "%s frontend CharacterData is the registry object" % String(expected_id))
        _check(frontend_entry.get("presentation") == roster_entry.get("presentation"), "%s frontend presentation is the registry object" % String(expected_id))
        var expected_source := "PACKAGE" if expected_id in PACKAGE_IDS else "LEGACY"
        _check(frontend_entry.get("source_type") == expected_source, "%s source is classified %s" % [String(expected_id), expected_source])
        select.p1_select.select(index)
        _check(select.p1_select.get_selected_id() == index, "P1 selects %s" % String(expected_id))
        _check(select.p1_select.get_selected_metadata() == expected_id, "P1 transfers stable ID %s" % String(expected_id))
        _check(select.model.entry(select.p1_select.get_selected_id()).get("character") == RosterRegistry.character_by_id(expected_id), "P1 resolves authoritative %s CharacterData" % String(expected_id))
        select.p2_select.select(index)
        _check(select.p2_select.get_selected_id() == index, "P2 selects %s" % String(expected_id))
        _check(select.p2_select.get_selected_metadata() == expected_id, "P2 transfers stable ID %s" % String(expected_id))
        _check(select.model.entry(select.p2_select.get_selected_id()).get("character") == RosterRegistry.character_by_id(expected_id), "P2 resolves authoritative %s CharacterData" % String(expected_id))
        var character := frontend_entry.get("character") as CharacterData
        var presentation := frontend_entry.get("presentation") as CharacterPresentationData
        print("[ROSTER] %s | %s | %s | %s | %s" % [
            String(expected_id), String(frontend_entry.get("display_name", "")), expected_source,
            character.resource_path, presentation.resource_path,
        ])
    _check(seen.size() == 14, "Frontend has zero duplicate and zero missing canonical IDs")
    await _dispose_current_scene()


func _verify_frontend_to_battle(id: StringName) -> void:
    var select := await _open_character_select()
    if select == null:
        _check(false, "%s frontend opens for battle smoke" % String(id))
        return
    var p1_index: int = select.model.index_for_id(id)
    var partner_id: StringName = &"alien_meow" if id == &"doge" else &"doge"
    var p2_index: int = select.model.index_for_id(partner_id)
    _check(p1_index >= 0 and p2_index >= 0, "%s and partner resolve by stable ID" % String(id))
    if p1_index < 0 or p2_index < 0:
        await _dispose_current_scene()
        return
    select.p1_select.select(p1_index)
    select.p2_select.select(p2_index)
    select.local_button.pressed.emit()
    await process_frame
    await process_frame
    var battle := current_scene as BattleScene
    _check(battle != null, "%s travels through real frontend into BattleScene" % String(id))
    if battle == null:
        await _dispose_current_scene()
        return
    var expected_character := RosterRegistry.character_by_id(id)
    var expected_presentation := RosterRegistry.presentation_by_id(id)
    _check(battle.character_a_data == expected_character, "%s BattleScene receives exact active CharacterData" % String(id))
    _check(battle.character_a_presentation == expected_presentation, "%s BattleScene receives exact active presentation" % String(id))
    _check(battle.simulation != null and battle.simulation.fighter_a.data == expected_character, "%s real Fighter receives exact active CharacterData" % String(id))
    _check(battle.simulation != null and battle.simulation.fighter_b.data == RosterRegistry.character_by_id(partner_id), "%s opponent selection is preserved" % String(id))
    await _dispose_current_scene()


func _open_character_select() -> ModeSelectScene:
    var select := SELECT_SCENE.instantiate() as ModeSelectScene
    if select == null:
        return null
    root.add_child(select)
    current_scene = select
    await process_frame
    return select


func _dispose_current_scene() -> void:
    if current_scene != null and is_instance_valid(current_scene):
        var previous := current_scene
        current_scene = null
        previous.queue_free()
        await process_frame


func _check(condition: bool, label: String) -> void:
    if condition:
        print("[PASS] %s" % label)
        return
    _failures += 1
    push_error("[FAIL] %s" % label)
