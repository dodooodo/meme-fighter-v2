# Responsibility: M2.1.5 InputButton naming and contextual ActionIntent migration regression suite.
# Owns: contract/migration tests only.
# Does NOT own: production combat behavior, move data, presentation.
# Dependencies: InputFrame, InputParser, ActionIntent, InputBuffer, BattleSimulation.
class_name Milestone215Tests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_input_button_contract()
    _test_neutral_light_intent()
    _test_down_light_intent()
    _test_up_heavy_intent()
    _test_facing_relative_heavy_context()
    _test_same_frame_light_heavy_tie_break()
    _test_intent_snapshot_stability()
    _test_buffered_context_stability_drives_crouch_low()
    _test_latest_intent_wins_with_full_context_replacement()
    _test_buffer_copies_intent()
    _test_existing_buffer_expiry_and_legality_contracts()
    print("\nM2.1.5 Contextual Action Intent tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 40000, p2_x: int = 100000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        character,
        character,
        null,
        null,
        Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS)
    )
    return battle

func _parse_intent(frame: InputFrame, facing: int) -> ActionIntent:
    var parser := InputParser.new()
    parser.update(frame, facing)
    return parser.normal_attack_pressed_intent()

func _tick_neutral(battle: BattleSimulation, count: int) -> void:
    for _i in range(count):
        var frame := battle.frame_number + 1
        battle.simulate_frame(InputFrame.neutral(frame), InputFrame.neutral(frame))

func _advance_p1_to_move_frame(battle: BattleSimulation, target_move_frame: int) -> void:
    while battle.fighter_a.move_runner.is_running() and battle.fighter_a.move_runner.move_frame < target_move_frame:
        _tick_neutral(battle, 1)

func _test_input_button_contract() -> void:
    var keys := InputFrame.InputButton.keys()
    for name in ["LIGHT", "HEAVY", "GUARD", "SPECIAL", "ULTIMATE"]:
        t.that(keys.has(name), "InputButton contains %s" % name)
    t.equal(keys.size(), 5, "InputButton has exactly five canonical action buttons")
    t.that(not keys.has("JUMP"), "InputButton excludes JUMP")
    t.that(not keys.has("CROUCH"), "InputButton excludes CROUCH")

func _test_neutral_light_intent() -> void:
    var intent := _parse_intent(InputFrame.with_light_press(10), 1)
    t.that(intent != null, "Neutral Light creates ActionIntent")
    t.equal(intent.action_button, InputFrame.InputButton.LIGHT, "Neutral Light intent action is LIGHT")
    t.equal(intent.source_frame, 10, "Neutral Light captures source frame")
    t.equal(intent.direction_x, 0, "Neutral Light captures neutral X")
    t.equal(intent.direction_y, 0, "Neutral Light captures neutral Y")
    t.that(not intent.forward_held and not intent.back_held, "Neutral Light has no forward/back context")

func _test_down_light_intent() -> void:
    var intent := _parse_intent(InputFrame.with_light_press(100, 0, -1), 1)
    t.equal(intent.action_button, InputFrame.InputButton.LIGHT, "Down+Light remains LIGHT intent")
    t.equal(intent.direction_y, -1, "Down+Light captures direction_y = -1")
    t.equal(intent.source_frame, 100, "Down+Light captures request frame")

func _test_up_heavy_intent() -> void:
    var intent := _parse_intent(InputFrame.with_heavy_press(101, 0, 1), 1)
    t.equal(intent.action_button, InputFrame.InputButton.HEAVY, "Up+Heavy creates HEAVY intent")
    t.equal(intent.direction_y, 1, "Up+Heavy captures direction_y = +1")

func _test_facing_relative_heavy_context() -> void:
    var right_forward := _parse_intent(InputFrame.with_heavy_press(110, 1, 0), 1)
    t.that(right_forward.forward_held and not right_forward.back_held, "Facing Right: World Right+Heavy captures Forward")
    var left_forward := _parse_intent(InputFrame.with_heavy_press(111, -1, 0), -1)
    t.that(left_forward.forward_held and not left_forward.back_held, "Facing Left: World Left+Heavy captures Forward")
    var right_back := _parse_intent(InputFrame.with_heavy_press(112, -1, 0), 1)
    t.that(right_back.back_held and not right_back.forward_held, "Facing Right: World Left+Heavy captures Back")
    var left_back := _parse_intent(InputFrame.with_heavy_press(113, 1, 0), -1)
    t.that(left_back.back_held and not left_back.forward_held, "Facing Left: World Right+Heavy captures Back")

func _test_same_frame_light_heavy_tie_break() -> void:
    var both := InputFrame.InputButton.LIGHT | InputFrame.InputButton.HEAVY
    var parser := InputParser.new()
    parser.update(InputFrame.new(120, 0, 0, both, both, 0), 1)
    var intent := parser.normal_attack_pressed_intent()
    t.equal(intent.action_button, InputFrame.InputButton.HEAVY, "Same-frame LIGHT+HEAVY keeps deterministic HEAVY tie-break")

func _test_intent_snapshot_stability() -> void:
    var parser := InputParser.new()
    parser.update(InputFrame.with_light_press(100, 0, -1), 1)
    var intent := parser.normal_attack_pressed_intent()
    parser.update(InputFrame.neutral(101), -1)
    t.equal(intent.source_frame, 100, "Existing intent source frame survives later Parser update")
    t.equal(intent.direction_y, -1, "Existing intent Down context survives later neutral Parser update")
    t.equal(intent.facing_at_request, 1, "Existing intent keeps facing at request time")
    t.that(not intent.forward_held and not intent.back_held, "Existing intent relative context is not recomputed from later facing")

func _test_buffered_context_stability_drives_crouch_low() -> void:
    var battle := _battle()
    var frame := battle.frame_number + 1
    battle.simulate_frame(InputFrame.with_light_press(frame), InputFrame.neutral(frame))
    _advance_p1_to_move_frame(battle, 16)

    frame = battle.frame_number + 1
    battle.simulate_frame(InputFrame.with_light_press(frame, 0, -1), InputFrame.neutral(frame))
    var buffered := battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(buffered != null, "Down+Light is buffered during recovery")
    t.equal(buffered.action_button, InputFrame.InputButton.LIGHT, "Buffered Down+Light preserves LIGHT action")
    t.equal(buffered.direction_y, -1, "Buffered Down context survives request frame")
    t.equal(buffered.source_frame, frame, "Buffered intent preserves original source frame")

    _tick_neutral(battle, 2)
    buffered = battle.fighter_a.input_buffer.peek_intent(battle.frame_number)
    t.that(buffered != null and buffered.direction_y == -1, "Buffered Down context remains stable through later neutral frames")
    _tick_neutral(battle, 1)
    t.equal(battle.fighter_a.move_runner.current_move_id(), MoveIds.CROUCH_LOW, "M2.2 consumes preserved request-frame Down context as Crouch Low")

func _test_latest_intent_wins_with_full_context_replacement() -> void:
    var buffer := InputBuffer.new()
    var first := ActionIntent.new(InputFrame.InputButton.LIGHT, 100, 0, -1, 1)
    var second := ActionIntent.new(InputFrame.InputButton.HEAVY, 101, 1, 0, 1)
    t.that(buffer.buffer_intent(first), "First contextual intent enters buffer")
    t.that(buffer.buffer_intent(second), "Second contextual intent replaces first")
    var buffered := buffer.peek_intent(101)
    t.equal(buffered.action_button, InputFrame.InputButton.HEAVY, "Latest intent replaces action button")
    t.equal(buffered.source_frame, 101, "Latest intent replaces source frame")
    t.equal(buffered.direction_x, 1, "Latest intent replaces direction X")
    t.equal(buffered.direction_y, 0, "Latest intent does not retain old Down context")
    t.that(buffered.forward_held and not buffered.back_held, "Latest intent replaces facing-relative context")
    t.equal(buffer.expiry_frame(), 106, "Latest intent resets expiry from its own source frame")

func _test_buffer_copies_intent() -> void:
    var buffer := InputBuffer.new()
    var source := ActionIntent.new(InputFrame.InputButton.LIGHT, 200, 0, -1, 1)
    buffer.buffer_intent(source)
    source.direction_y = 1
    source.action_button = InputFrame.InputButton.HEAVY
    var buffered := buffer.peek_intent(200)
    t.equal(buffered.action_button, InputFrame.InputButton.LIGHT, "Buffer owns a safe copy of action intent")
    t.equal(buffered.direction_y, -1, "Buffer copy cannot be mutated through source ActionIntent")

func _test_existing_buffer_expiry_and_legality_contracts() -> void:
    var buffer := InputBuffer.new()
    buffer.buffer_intent(ActionIntent.new(InputFrame.InputButton.LIGHT, 300))
    t.that(buffer.has_pending(305), "5F contextual buffer remains valid through expiry frame")
    t.that(not buffer.has_pending(306), "Contextual buffer expires after 5F window")

    var battle := _battle()
    battle.fighter_a.input_buffer.buffer_intent(ActionIntent.new(InputFrame.InputButton.HEAVY, 1, 1, 0, 1))
    battle.fighter_a.combatant.hitstun_remaining = 3
    battle.simulate_frame(InputFrame.neutral(1), InputFrame.neutral(1))
    t.that(not battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Hitstun still clears contextual normal buffer")
    t.that(not battle.fighter_a.move_runner.is_running(), "Contextual buffer cannot bypass Hitstun legality")
