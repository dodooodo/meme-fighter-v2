# Responsibility: M1.5 Input Contract, parser, and Move Registry migration regression suite.
# Owns: migration tests only.
# Does NOT own: production behavior or presentation.
# Dependencies: InputFrame, InputParser, MoveSetData, MoveRegistry, BattleSimulation.
class_name Milestone15Tests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_input_button_contract_has_no_jump_or_crouch()
    _test_vertical_direction_is_canonical()
    _test_all_action_button_edges()
    _test_parser_directions_and_facing()
    _test_parser_all_action_buttons()
    _test_move_registry_generic_fighter()
    _test_move_registry_missing_id()
    _test_move_registry_duplicate_detection()
    _test_stand_light_starts_through_registry()
    print("\nM1.5 migration tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_input_button_contract_has_no_jump_or_crouch() -> void:
    var keys := InputFrame.InputButton.keys()
    t.that(not keys.has("JUMP"), "InputFrame action bits do not contain JUMP")
    t.that(not keys.has("CROUCH"), "InputFrame action bits do not contain CROUCH")
    t.equal(keys.size(), 5, "InputFrame has exactly five canonical action buttons")

func _test_vertical_direction_is_canonical() -> void:
    var up := InputFrame.new(1, 0, 1)
    var down := InputFrame.new(2, 0, -1)
    t.equal(up.direction_y, 1, "Up is represented only as direction_y = +1")
    t.equal(down.direction_y, -1, "Down is represented only as direction_y = -1")
    t.equal(up.held_bits, 0, "Up does not set an action bit")
    t.equal(down.held_bits, 0, "Down does not set an action bit")

func _test_all_action_button_edges() -> void:
    var buttons: Array[int] = [
        InputFrame.InputButton.LIGHT,
        InputFrame.InputButton.HEAVY,
        InputFrame.InputButton.GUARD,
        InputFrame.InputButton.SPECIAL,
        InputFrame.InputButton.ULTIMATE,
    ]
    var names: Array[String] = ["LIGHT", "HEAVY", "GUARD", "SPECIAL", "ULTIMATE"]
    for i in range(buttons.size()):
        var button := buttons[i]
        var frame := InputFrame.new(1, 0, 0, button, button, button)
        t.that(frame.is_pressed(button), names[i] + " pressed bit parses")
        t.that(frame.is_held(button), names[i] + " held bit parses")
        t.that(frame.is_released(button), names[i] + " released bit parses")

func _test_parser_directions_and_facing() -> void:
    var parser := InputParser.new()
    parser.update(InputFrame.new(1, -1, 1), 1)
    t.that(parser.world_left_held, "Parser recognizes world left")
    t.that(parser.up_held, "Parser recognizes up")
    t.that(parser.back_held and not parser.forward_held, "Facing Right: world left is Back")
    parser.update(InputFrame.new(2, 1, -1), 1)
    t.that(parser.world_right_held, "Parser recognizes world right")
    t.that(parser.down_held, "Parser recognizes down")
    t.that(parser.forward_held and not parser.back_held, "Facing Right: world right is Forward")
    parser.update(InputFrame.new(3, 1, 0), -1)
    t.that(parser.back_held and not parser.forward_held, "Facing Left: world right is Back")
    parser.update(InputFrame.new(4, -1, 0), -1)
    t.that(parser.forward_held and not parser.back_held, "Facing Left: world left is Forward")

func _test_parser_all_action_buttons() -> void:
    var buttons: Array[int] = [InputFrame.InputButton.LIGHT, InputFrame.InputButton.HEAVY, InputFrame.InputButton.GUARD, InputFrame.InputButton.SPECIAL, InputFrame.InputButton.ULTIMATE]
    var all_bits := 0
    for button in buttons:
        all_bits |= button
    var parser := InputParser.new()
    parser.update(InputFrame.new(1, 0, 0, all_bits, all_bits, all_bits), 1)
    t.that(parser.light_pressed and parser.light_held and parser.light_released, "Parser exposes Light pressed/held/released")
    t.that(parser.heavy_pressed and parser.heavy_held and parser.heavy_released, "Parser exposes Heavy pressed/held/released")
    t.that(parser.guard_pressed and parser.guard_held and parser.guard_released, "Parser exposes Guard pressed/held/released")
    t.that(parser.special_pressed and parser.special_held and parser.special_released, "Parser exposes Special pressed/held/released")
    t.that(parser.ultimate_pressed and parser.ultimate_held and parser.ultimate_released, "Parser exposes Ultimate pressed/held/released")

func _test_move_registry_generic_fighter() -> void:
    var registry := MoveRegistry.new()
    t.that(character.move_set != null, "Generic Fighter owns a MoveSetData")
    t.that(registry.configure(character.move_set), "Generic Fighter MoveSet validates")
    t.that(registry.has_move(MoveIds.STAND_LIGHT), "Generic Fighter MoveSet contains stand_light")
    var light := registry.get_move(MoveIds.STAND_LIGHT)
    t.that(light != null and light.id == MoveIds.STAND_LIGHT, "Registry retrieves stand_light by stable ID")

func _test_move_registry_missing_id() -> void:
    var registry := MoveRegistry.new()
    registry.configure(character.move_set)
    t.that(not registry.has_move(&"missing_move"), "Missing move ID is reported absent")
    t.that(registry.get_move(&"missing_move") == null, "Missing move ID returns null, never unrelated MoveData")

func _test_move_registry_duplicate_detection() -> void:
    var first := MoveData.new()
    first.id = &"duplicate_test"
    var second := MoveData.new()
    second.id = &"duplicate_test"
    var move_set := MoveSetData.new()
    var duplicate_moves: Array[MoveData] = [first, second]
    move_set.moves = duplicate_moves
    var registry := MoveRegistry.new()
    t.that(not registry.configure(move_set), "Duplicate MoveData IDs fail registry validation")
    t.that(registry.validation_errors().size() > 0, "Duplicate MoveData IDs produce a clear validation error")

func _test_stand_light_starts_through_registry() -> void:
    var battle := BattleSimulation.new()
    battle.configure(character, character)
    var input := InputFrame.with_light_press(1)
    battle.simulate_frame(input, InputFrame.neutral(1))
    t.that(battle.fighter_a.move_registry.has_move(MoveIds.STAND_LIGHT), "Fighter runtime registry contains Stand Light")
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Light starts via MoveRegistry lookup")
    t.equal(battle.fighter_a.move_runner.move_frame, 2, "Whiffing frame 1 advances normally after registry-based start")
