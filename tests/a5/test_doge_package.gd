class_name A5DogePackageTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const DOGE_MANIFEST_PATH := "res://content/characters/doge/character_manifest.tres"
const DOGE_ANIMATION_MANIFEST_PATH := "res://assets/characters/doge/animations/manifest.json"
const DOGE_SUPER_ANIMATION_MANIFEST_PATH := "res://assets/characters/doge/animations/doge_super_manifest.json"
const DOGE_MOVE_ROOT := "res://content/characters/doge/gameplay/moves/"
const EXPECTED_MOVE_IDS: Array[StringName] = [
    &"stand_light",
    &"stand_heavy",
    &"crouch_low",
    &"air_attack",
    &"ground_throw",
    &"special_neutral",
    &"doge_rush_l1",
    &"doge_rush_l2",
    &"doge_rush_l3",
    &"ultimate",
    &"doge_super_heavy",
]

var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_package_and_catalog_discovery()
    _test_split_moves_and_production_presentation()
    _test_production_presentation_feet_pivots()
    _test_packaged_charge_regression()
    _test_packaged_charge_interruption_reset_cancel_armor_and_mode()
    _test_packaged_charge_replay()
    print("\nA5 Doge package tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _manifest() -> CharacterManifest:
    return load(DOGE_MANIFEST_PATH) as CharacterManifest if ResourceLoader.exists(DOGE_MANIFEST_PATH) else null

func _test_package_and_catalog_discovery() -> void:
    t.that(ResourceLoader.exists(DOGE_MANIFEST_PATH), "Doge package manifest exists")
    var manifest := _manifest()
    t.that(manifest != null and manifest.is_valid(), "Doge package manifest validates")
    if manifest == null:
        return
    t.equal(manifest.id, &"doge", "Doge package preserves stable character ID")
    t.that(manifest.portrait != null, "Doge package owns a selectable portrait")
    t.equal(RosterRegistry.character_by_id(&"doge"), manifest.gameplay_resource, "Compatibility roster routes Doge through package gameplay")
    t.equal(RosterRegistry.presentation_by_id(&"doge"), manifest.presentation_resource, "Compatibility roster routes Doge through package presentation")
    t.that(not ResourceLoader.exists("res:/" + "/data/characters/doge.tres"), "Former central Doge character resource is retired")
    t.that(not ResourceLoader.exists("res:/" + "/data/move_sets/roster/doge_move_set.tres"), "Former central Doge move set is retired")

    var catalog := CharacterCatalog.new()
    t.that(catalog.has_method("discover_builtin"), "CharacterCatalog exposes built-in package discovery")
    if not catalog.has_method("discover_builtin"):
        return
    t.that(bool(catalog.call("discover_builtin")), "Built-in package discovery succeeds atomically")
    var ids: Array[StringName] = []
    for item: CharacterManifest in catalog.list_manifests():
        if item.available:
            ids.append(item.id)
            t.that(item.portrait != null, "%s package has a character-select portrait" % String(item.id))
    t.equal(ids, [&"doge", &"magic_orange_cat", &"niu_lai", &"salad_cat"], "Available package roster is sorted and includes Niu Lai")

func _test_split_moves_and_production_presentation() -> void:
    var manifest := _manifest()
    if manifest == null:
        return
    var character := manifest.gameplay_resource
    t.that(character != null and character.move_set != null, "Doge package loads gameplay and move set")
    if character == null or character.move_set == null:
        return
    t.equal(character.move_set.moves.size(), EXPECTED_MOVE_IDS.size(), "Doge keeps all eleven authored moves")
    var actual_ids: Array[StringName] = []
    for move: MoveData in character.move_set.moves:
        t.that(move != null, "Doge move set contains no null MoveData")
        if move == null:
            continue
        actual_ids.append(move.id)
        t.that(move.resource_path.begins_with(DOGE_MOVE_ROOT), "%s is package-owned MoveData" % String(move.id))
    actual_ids.sort()
    var expected := EXPECTED_MOVE_IDS.duplicate()
    expected.sort()
    t.equal(actual_ids, expected, "Doge split move resources preserve every stable move ID")

    var presentation := manifest.presentation_resource
    t.that(presentation != null and presentation.fighter_visual_scene != null, "Doge package loads fighter presentation")
    if presentation == null or presentation.fighter_visual_scene == null:
        return
    t.that(presentation.fighter_visual_scene.resource_path.contains("visuals/production"), "Doge uses a production fighter visual scene")
    t.that(not presentation.fighter_visual_scene.resource_path.contains("greybox"), "Doge no longer uses greybox presentation")
    t.that(presentation.state_bindings.size() >= 17, "Doge binds the full authored state presentation set")
    t.equal(presentation.move_bindings.size(), EXPECTED_MOVE_IDS.size(), "Doge binds every authored move presentation")
    t.that(presentation.mode_binding(&"super_doge") != null, "Doge binds its authoritative Super Doge mode visual")

func _test_production_presentation_feet_pivots() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOGE_ANIMATION_MANIFEST_PATH))
    t.that(parsed is Dictionary, "Doge animation manifest is valid JSON")
    if not (parsed is Dictionary):
        return
    t.equal(String(parsed.get("pivot_convention", "")), "FEET_CENTER", "Doge declares the shared feet-center pivot contract")
    var animations: Variant = parsed.get("animations", [])
    t.that(animations is Array and not animations.is_empty(), "Doge manifest carries per-animation frame metadata")
    if not (animations is Array) or animations.is_empty():
        return
    var keys: Dictionary = {}
    for animation: Variant in animations:
        t.that(animation is Dictionary, "Doge animation metadata entry is structured")
        if not (animation is Dictionary):
            continue
        var key := StringName(String(animation.get("key", "")))
        keys[key] = true
        var frames: Variant = animation.get("frames", [])
        t.that(frames is Array and not frames.is_empty(), "%s exposes frame pivot metadata" % String(key))
        if not (frames is Array):
            continue
        for frame: Variant in frames:
            var pivot: Variant = frame.get("pivot_pixels", []) if frame is Dictionary else []
            t.that(pivot is Array and pivot.size() == 2, "%s frame anchors its authored feet center" % String(key))

    var presentation := _manifest().presentation_resource
    var visual := presentation.fighter_visual_scene.instantiate()
    var sprite := visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    t.that(sprite != null and not sprite.centered, "Doge visual uses the top-left sprite anchor required by per-frame pivots")
    t.equal(visual.get_script().resource_path, "res://presentation/visuals/production/production_fighter_visual.gd", "Doge uses the shared production visual adapter without a character-specific pivot exception")
    if sprite != null and sprite.sprite_frames != null:
        for animation_name: StringName in sprite.sprite_frames.get_animation_names():
            t.that(keys.has(animation_name), "Doge manifest covers SpriteFrames animation %s" % String(animation_name))
    visual.free()

    var super_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOGE_SUPER_ANIMATION_MANIFEST_PATH))
    t.that(super_parsed is Dictionary, "Super Doge animation manifest is valid JSON")
    if super_parsed is Dictionary:
        t.equal(String(super_parsed.get("pivot_convention", "")), "FEET_CENTER", "Super Doge declares the shared feet-center pivot contract")
        var super_animations: Variant = super_parsed.get("animations", [])
        t.that(super_animations is Array and not super_animations.is_empty(), "Super Doge manifest carries per-animation frame metadata")
    var mode_binding := presentation.mode_binding(&"super_doge")
    var super_visual := mode_binding.fighter_visual_scene.instantiate()
    var super_sprite := super_visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    t.that(super_sprite != null and not super_sprite.centered, "Super Doge uses top-left per-frame pivot coordinates")
    t.equal(super_visual.get_script().resource_path, "res://presentation/visuals/production/production_fighter_visual.gd", "Super Doge also uses the shared production visual adapter")
    super_visual.free()

func _test_packaged_charge_regression() -> void:
    var manifest := _manifest()
    if manifest == null or manifest.gameplay_resource == null:
        return
    var registry := MoveRegistry.new()
    t.that(registry.configure(manifest.gameplay_resource.move_set), "Packaged Doge MoveRegistry configures")
    var entry := registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    t.that(entry != null and entry.charge_special_data != null, "Packaged Doge Special owns typed charge data")
    if entry == null or entry.charge_special_data == null:
        return
    t.equal(entry.charge_special_data.level_2_threshold_frames, 24, "Packaged Doge Lv2 threshold remains 24F")
    t.equal(entry.charge_special_data.level_3_threshold_frames, 54, "Packaged Doge Lv3 threshold remains 54F")
    t.equal(entry.charge_special_data.move_id_for_charge_frames(23), &"doge_rush_l1", "23F Doge charge releases Lv1")
    t.equal(entry.charge_special_data.move_id_for_charge_frames(24), &"doge_rush_l2", "24F Doge charge releases Lv2")
    t.equal(entry.charge_special_data.move_id_for_charge_frames(53), &"doge_rush_l2", "53F Doge charge remains Lv2")
    t.equal(entry.charge_special_data.move_id_for_charge_frames(54), &"doge_rush_l3", "54F Doge charge releases Lv3")
    t.that(registry.get_move(&"doge_rush_l3").armor_data != null, "Packaged Doge Lv3 retains strike armor")
    t.equal(manifest.gameplay_resource.mechanics.modes[0].mode_id, &"super_doge", "Packaged Doge retains data-defined Super Doge mode")

    var battle := BattleSimulation.new()
    battle.configure(manifest.gameplay_resource, manifest.gameplay_resource, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(100000, BattleSimulation.GROUND_Y_UNITS))
    _tick_special(battle, true, true)
    for _frame in range(2, 31):
        _tick_special(battle, true)
    var snapshot := battle.capture_state()
    var signature := battle.state_signature()
    t.equal(snapshot.fighter_a.charge_frames, 30, "Doge charge frame count is snapshot state")
    _tick_special(battle, false, false, true)
    t.equal(battle.fighter_a.move_runner.current_move_id(), &"doge_rush_l2", "Doge 30F release starts packaged Lv2 move")
    t.that(battle.restore_state(snapshot), "Doge charging snapshot restores")
    t.equal(battle.state_signature(), signature, "Doge charging snapshot restores exact deterministic hash")

func _test_packaged_charge_interruption_reset_cancel_armor_and_mode() -> void:
    var manifest := _manifest()
    if manifest == null or manifest.gameplay_resource == null:
        return
    var interrupted := _doge_battle(true)
    var first_frame := interrupted.frame_number + 1
    interrupted.simulate_frame(_special_input(first_frame, true, true), InputFrame.with_light_press(first_frame))
    for _frame in range(2, 12):
        var frame := interrupted.frame_number + 1
        interrupted.simulate_frame(_special_input(frame, true), InputFrame.neutral(frame))
        if interrupted.fighter_a.combatant.hitstun_remaining > 0:
            break
    t.that(interrupted.fighter_a.combatant.hitstun_remaining > 0, "Packaged Doge charge remains vulnerable to strike interruption")
    t.that(interrupted.fighter_a.state_machine.state != FighterStateMachine.State.CHARGE, "Doge hit interruption exits Charge")
    t.equal(interrupted.fighter_a.state_machine.charge_frames, 0, "Doge hit interruption clears authoritative charge frames")

    var reset := _doge_battle()
    _tick_special(reset, true, true)
    for _frame in range(2, 18):
        _tick_special(reset, true)
    reset.reset_full_match()
    t.equal(reset.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Doge full-match reset exits Charge")
    t.equal(reset.fighter_a.state_machine.charge_frames, 0, "Doge full-match reset clears charge frames")

    var cancel := _doge_battle()
    var heavy := cancel.fighter_a.move_registry.get_move(MoveIds.STAND_HEAVY)
    t.that(cancel.fighter_a.move_runner.start_move(heavy), "Packaged Doge Heavy starts for charge-cancel regression")
    cancel.fighter_a.hitbox_owner.begin_attack_instance(cancel.fighter_a.move_runner.attack_instance_id)
    cancel.fighter_a.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    cancel.fighter_a.move_runner.move_frame = 12
    cancel.fighter_a.move_runner.connected_hit = true
    _tick_special(cancel, true, true)
    t.equal(cancel.fighter_a.state_machine.state, FighterStateMachine.State.CHARGE, "Packaged Doge Heavy hit-cancels into Charge")
    t.equal(cancel.fighter_a.state_machine.charge_entry_move_id, MoveIds.SPECIAL_NEUTRAL, "Doge Heavy cancel preserves canonical charge entry ID")

    var armored := _doge_battle()
    var level_three := armored.fighter_a.move_registry.get_move(&"doge_rush_l3")
    t.that(armored.fighter_a.move_runner.start_move(level_three), "Packaged Doge Lv3 starts for armor regression")
    armored.fighter_a.mechanics_runtime.begin_move_defenses(level_three, armored.fighter_a.move_runner.attack_instance_id)
    armored.fighter_a.move_runner.move_frame = 7
    t.that(armored.fighter_a.mechanics_runtime.armor_active(armored.fighter_a.move_runner, HitResult.AttackSourceKind.FIGHTER_BODY), "Packaged Doge Lv3 activates one-hit strike armor in authored frames")
    armored.fighter_a.mechanics_runtime.consume_armor()
    t.that(not armored.fighter_a.mechanics_runtime.armor_active(armored.fighter_a.move_runner, HitResult.AttackSourceKind.FIGHTER_BODY), "Packaged Doge Lv3 armor is consumed after one strike")

    var super_battle := _doge_battle()
    t.that(super_battle.fighter_a.mode.enter(&"super_doge", 480, super_battle.frame_number), "Packaged Doge enters data-defined Super Doge mode")
    var mode_frame := super_battle.frame_number + 1
    super_battle.simulate_frame(InputFrame.with_heavy_press(mode_frame), InputFrame.neutral(mode_frame))
    t.equal(super_battle.fighter_a.move_runner.current_move_id(), &"doge_super_heavy", "Super Doge replaces canonical Heavy through generic mode data")

func _test_packaged_charge_replay() -> void:
    var manifest := _manifest()
    if manifest == null or manifest.gameplay_resource == null:
        return
    var doge := manifest.gameplay_resource
    var live := _doge_battle()
    var recorder := ReplayRecorder.new()
    t.that(recorder.begin_recording(&"versus", doge.id, doge.id), "Packaged Doge charge replay recording begins")
    live.set_replay_recorder(recorder)
    for frame in range(1, 76):
        var p1: InputFrame
        if frame == 1:
            p1 = _special_input(frame, true, true)
        elif frame <= 60:
            p1 = _special_input(frame, true)
        elif frame == 61:
            p1 = _special_input(frame, false, false, true)
        else:
            p1 = InputFrame.neutral(frame)
        live.simulate_frame(p1, InputFrame.neutral(frame))
    t.equal(live.fighter_a.move_runner.current_move_id(), &"doge_rush_l3", "Recorded packaged Doge 60F release derives Lv3")
    var live_hash := live.state_signature()
    t.that(recorder.finish_recording(live_hash), "Packaged Doge charge replay recording finishes with hash")
    var replay := recorder.replay_data()
    var source_a := ReplayInputSource.new()
    var source_b := ReplayInputSource.new()
    t.that(source_a.configure(replay, 1) and source_b.configure(replay, 2), "Packaged Doge replay configures both normalized input streams")
    var playback := BattleSimulation.new()
    playback.configure(doge, doge, source_a, source_b, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(100000, BattleSimulation.GROUND_Y_UNITS))
    for _frame in range(replay.frame_count()):
        playback.sample_and_simulate_frame()
    t.equal(playback.state_signature(), live_hash, "Packaged Doge charge replay reproduces exact deterministic hash")

func _doge_battle(close: bool = false) -> BattleSimulation:
    var doge := _manifest().gameplay_resource
    var battle := BattleSimulation.new()
    battle.configure(doge, doge, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(58000 if close else 100000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _special_input(frame: int, held: bool, pressed: bool = false, released: bool = false) -> InputFrame:
    var bit := InputFrame.InputButton.SPECIAL
    return InputFrame.new(frame, 0, 0, bit if held else 0, bit if pressed else 0, bit if released else 0)

func _tick_special(battle: BattleSimulation, held: bool, pressed: bool = false, released: bool = false) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(_special_input(frame, held, pressed, released), InputFrame.neutral(frame))
