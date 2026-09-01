# Responsibility: M3 Special/Ultimate input, data, timing, cost, legality, and M2 input regression suite.
class_name Milestone3MoveTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var character: CharacterData

func run_all() -> int:
    character = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_keyboard_action_bit_composition()
    _test_action_priority_and_mapping()
    _test_special_data_and_timing()
    _test_special_runtime_outcome_and_actionable_frame()
    _test_ultimate_data_and_timing()
    _test_ultimate_runtime_outcome_and_actionable_frame()
    _test_special_ground_air_and_whiff_rules()
    _test_ultimate_meter_spend_and_legality()
    _test_guard_priority_and_throw_air_regression()
    print("\nM3 Special/Ultimate tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(p1_x: int = 30000, p2_x: int = 100000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(character, character, null, null, Vector2i(p1_x, BattleSimulation.GROUND_Y_UNITS), Vector2i(p2_x, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var f := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(f), b if b != null else InputFrame.neutral(f))

func _guard_with_action(frame: int, action_bit: int) -> InputFrame:
    var guard := InputFrame.InputButton.GUARD
    return InputFrame.new(frame, 0, 0, guard | action_bit, guard | action_bit, 0)

func _start_lv1_special(battle: BattleSimulation, defender_guarding: bool = false) -> void:
    var f := battle.frame_number + 1
    _tick(battle, InputFrame.with_special_press(f), InputFrame.new(f, 0, 0, InputFrame.InputButton.GUARD, InputFrame.InputButton.GUARD, 0) if defender_guarding else null)
    for _i in range(2):
        f = battle.frame_number + 1
        _tick(battle, InputFrame.new(f, 0, 0, 0, 0, InputFrame.InputButton.SPECIAL), InputFrame.new(f, 0, 0, InputFrame.InputButton.GUARD, 0, 0) if defender_guarding else null)

func _test_keyboard_action_bit_composition() -> void:
    t.equal(KeyboardInputSource.compose_action_bits(false, false, false, true, false), InputFrame.InputButton.SPECIAL, "KeyboardInputSource canonical action composition produces SPECIAL bit for its Special key state")
    t.equal(KeyboardInputSource.compose_action_bits(false, false, false, false, true), InputFrame.InputButton.ULTIMATE, "KeyboardInputSource canonical action composition produces ULTIMATE bit for its Ultimate key state")
    t.equal(KeyboardInputSource.compose_action_bits(false, true, false, true, true), InputFrame.InputButton.HEAVY | InputFrame.InputButton.SPECIAL | InputFrame.InputButton.ULTIMATE, "KeyboardInputSource composes simultaneous normalized action bits without gameplay interpretation")

func _test_action_priority_and_mapping() -> void:
    var parser := InputParser.new()
    var all_bits := InputFrame.InputButton.LIGHT | InputFrame.InputButton.HEAVY | InputFrame.InputButton.SPECIAL | InputFrame.InputButton.ULTIMATE
    parser.update(InputFrame.new(1, 0, 0, all_bits, all_bits, 0), 1)
    var intent := parser.action_pressed_intent()
    t.equal(intent.action_button, InputFrame.InputButton.ULTIMATE, "Same-frame action priority chooses ULTIMATE first")

    var no_ultimate := InputFrame.InputButton.LIGHT | InputFrame.InputButton.HEAVY | InputFrame.InputButton.SPECIAL
    parser.update(InputFrame.new(2, 0, 0, no_ultimate, no_ultimate, 0), 1)
    t.equal(parser.action_pressed_intent().action_button, InputFrame.InputButton.SPECIAL, "Same-frame priority chooses SPECIAL over HEAVY/LIGHT")

    var forward_heavy := ActionIntent.new(InputFrame.InputButton.HEAVY, 3, 1, 0, 1)
    t.equal(ActionMoveMap.ground_move_id_for_intent(forward_heavy), MoveIds.GROUND_THROW, "Forward+Heavy Throw precedence remains intact")
    t.equal(ActionMoveMap.ground_move_id_for_intent(ActionIntent.new(InputFrame.InputButton.HEAVY, 3, 0, 0, 1)), MoveIds.STAND_HEAVY, "Neutral+Heavy remains Stand Heavy")
    t.equal(ActionMoveMap.ground_move_id_for_intent(ActionIntent.new(InputFrame.InputButton.SPECIAL, 3, 0, 0, 1)), MoveIds.SPECIAL_NEUTRAL, "Ground SPECIAL maps to special_neutral")
    t.equal(ActionMoveMap.ground_move_id_for_intent(ActionIntent.new(InputFrame.InputButton.ULTIMATE, 3, 0, 0, 1)), MoveIds.ULTIMATE, "Ground ULTIMATE maps to ultimate")
    t.equal(ActionMoveMap.air_move_id_for_intent(ActionIntent.new(InputFrame.InputButton.SPECIAL, 3, 0, 0, 1)), &"", "Air SPECIAL has no M3 move mapping")
    t.equal(ActionMoveMap.air_move_id_for_intent(ActionIntent.new(InputFrame.InputButton.ULTIMATE, 3, 0, 0, 1)), &"", "Air ULTIMATE has no M3 move mapping")

func _test_special_data_and_timing() -> void:
    var registry := MoveRegistry.new()
    t.that(registry.configure(character.move_set), "MoveSet configures for Special data")
    var move := registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    t.that(move != null, "Special exists in MoveRegistry")
    t.equal(move.startup_frames, 10, "Special startup = 10F")
    t.equal(move.active_frames, 4, "Special active = 4F")
    t.equal(move.recovery_frames, 18, "Special recovery = 18F")
    t.equal(move.total_frames(), 32, "Special timeline totals 32F and is actionable on F33")
    t.equal(move.phase_for_frame(10), &"STARTUP", "Special frame 10 is Startup")
    t.equal(move.phase_for_frame(11), &"ACTIVE", "Special frame 11 is first Active")
    t.equal(move.phase_for_frame(14), &"ACTIVE", "Special frame 14 is last Active")
    t.equal(move.phase_for_frame(15), &"RECOVERY", "Special frame 15 enters Recovery")
    t.equal(move.phase_for_frame(32), &"RECOVERY", "Special frame 32 is final Recovery")
    t.equal(move.phase_for_frame(33), &"COMPLETE", "Special frame 33 is actionable/complete")
    t.equal(move.damage, 110, "Special damage = 110")
    t.equal(move.hitstun_frames, 20, "Special hitstun = 20F")
    t.equal(move.blockstun_frames, 14, "Special blockstun = 14F")
    t.equal(move.hitstop_attacker, 6, "Special attacker hitstop = 6F")
    t.equal(move.hitstop_defender, 6, "Special defender hitstop = 6F")
    t.equal(move.hit_level, MoveData.HitLevel.MID, "Special HitLevel = MID")
    t.equal(move.knockback_x_units, 1100, "Special knockback X = 1100")
    t.equal(move.knockback_y_units, 0, "Special knockback Y = 0")
    t.equal(move.hitbox.offset, Vector2(82, -76), "Special static hitbox offset matches prototype")
    t.equal(move.hitbox.size, Vector2(120, 88), "Special static hitbox size matches prototype")

func _test_special_runtime_outcome_and_actionable_frame() -> void:
    var hit := BattleSimulation.new()
    hit.configure(character, character, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(58000, BattleSimulation.GROUND_Y_UNITS))
    _start_lv1_special(hit)
    for _i in range(10):
        _tick(hit)
    t.equal(hit.fighter_b.combatant.hp, 4890, "Special runtime HIT applies exactly 110 damage")
    t.equal(hit.fighter_b.combatant.hitstun_remaining, 20, "Special runtime HIT installs the configured 20F hitstun")
    t.equal(hit.fighter_a.combatant.hitstop_remaining, 5, "Special runtime HIT installs 6F attacker hitstop before same-tick status decrement")
    t.equal(hit.fighter_b.combatant.hitstop_remaining, 5, "Special runtime HIT installs 6F defender hitstop before same-tick status decrement")
    t.equal(hit.fighter_b.combatant.knockback_velocity_x_units, 1100, "Special runtime HIT applies 1100 horizontal knockback")
    t.equal(hit.fighter_b.combatant.knockback_velocity_y_units, 0, "Special runtime HIT applies zero vertical knockback")

    var block := BattleSimulation.new()
    block.configure(character, character, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(58000, BattleSimulation.GROUND_Y_UNITS))
    var guard_bit := InputFrame.InputButton.GUARD
    _start_lv1_special(block, true)
    for _i in range(10):
        var f := block.frame_number + 1
        _tick(block, null, InputFrame.new(f, 0, 0, guard_bit, 0, 0))
    t.equal(block.fighter_b.combatant.hp, 5000, "Special BLOCK does no direct damage with zero chip")
    t.equal(block.fighter_b.combatant.blockstun_remaining, 14, "Special BLOCK installs the configured 14F blockstun")

    var timing := _battle()
    _start_lv1_special(timing)
    t.equal(timing.fighter_a.state_machine.state, FighterStateMachine.State.GROUND_ATTACK, "Minimum charge commits Special into its attack state")
    while timing.fighter_a.move_runner.move_frame < 32:
        _tick(timing)
    t.equal(timing.fighter_a.move_runner.move_frame, 32, "Lv1 Special is still running final Recovery move frame 32")
    t.equal(timing.fighter_a.move_runner.phase(), &"RECOVERY", "Lv1 Special runtime phase is Recovery on move frame 32")
    _tick(timing)
    t.that(not timing.fighter_a.move_runner.is_running(), "Lv1 Special is no longer running after move frame 32 resolves")
    _tick(timing, InputFrame.with_light_press(timing.frame_number + 1))
    t.equal(timing.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Lv1 Special is actionable on the next simulation frame through normal move-start path")

func _test_ultimate_data_and_timing() -> void:
    var registry := MoveRegistry.new()
    registry.configure(character.move_set)
    var move := registry.get_move(MoveIds.ULTIMATE)
    t.that(move != null, "Ultimate exists in MoveRegistry")
    t.equal(move.startup_frames, 14, "Ultimate startup = 14F")
    t.equal(move.active_frames, 5, "Ultimate active = 5F")
    t.equal(move.recovery_frames, 32, "Ultimate recovery = 32F")
    t.equal(move.total_frames(), 51, "Ultimate timeline totals 51F and is actionable on F52")
    t.equal(move.phase_for_frame(14), &"STARTUP", "Ultimate frame 14 is Startup")
    t.equal(move.phase_for_frame(15), &"ACTIVE", "Ultimate frame 15 is first Active")
    t.equal(move.phase_for_frame(19), &"ACTIVE", "Ultimate frame 19 is last Active")
    t.equal(move.phase_for_frame(20), &"RECOVERY", "Ultimate frame 20 enters Recovery")
    t.equal(move.phase_for_frame(51), &"RECOVERY", "Ultimate frame 51 is final Recovery")
    t.equal(move.phase_for_frame(52), &"COMPLETE", "Ultimate frame 52 is actionable/complete")
    t.equal(move.damage, 260, "Ultimate damage = 260")
    t.equal(move.hitstun_frames, 28, "Ultimate hitstun = 28F")
    t.equal(move.blockstun_frames, 18, "Ultimate blockstun = 18F")
    t.equal(move.hitstop_attacker, 10, "Ultimate attacker hitstop = 10F")
    t.equal(move.hitstop_defender, 10, "Ultimate defender hitstop = 10F")
    t.equal(move.hit_level, MoveData.HitLevel.MID, "Ultimate HitLevel = MID")
    t.equal(move.knockback_x_units, 1600, "Ultimate knockback X = 1600")
    t.equal(move.knockback_y_units, -500, "Ultimate knockback Y = -500")
    t.equal(move.meter_cost, 100, "Ultimate meter cost = 100")
    t.equal(move.hitbox.offset, Vector2(94, -82), "Ultimate static hitbox offset matches prototype")
    t.equal(move.hitbox.size, Vector2(154, 108), "Ultimate static hitbox size matches prototype")
    t.equal(move.cancel_windows.size(), 0, "Ultimate has no cancel windows")

func _test_ultimate_runtime_outcome_and_actionable_frame() -> void:
    var hit := BattleSimulation.new()
    hit.configure(character, character, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(58000, BattleSimulation.GROUND_Y_UNITS))
    hit.fighter_a.meter.gain(100)
    _tick(hit, InputFrame.with_ultimate_press(1))
    for _i in range(14):
        _tick(hit)
    t.equal(hit.fighter_b.combatant.hp, 4740, "Ultimate runtime HIT applies exactly 260 damage")
    t.equal(hit.fighter_b.combatant.hitstun_remaining, 28, "Ultimate runtime HIT installs the configured 28F hitstun")
    t.equal(hit.fighter_a.combatant.hitstop_remaining, 9, "Ultimate runtime HIT installs 10F attacker hitstop before same-tick status decrement")
    t.equal(hit.fighter_b.combatant.hitstop_remaining, 9, "Ultimate runtime HIT installs 10F defender hitstop before same-tick status decrement")
    t.equal(hit.fighter_b.combatant.knockback_velocity_x_units, 1600, "Ultimate runtime HIT applies 1600 horizontal knockback")
    t.equal(hit.fighter_b.combatant.knockback_velocity_y_units, -500, "Ultimate runtime HIT applies -500 vertical knockback")
    t.equal(hit.fighter_a.meter.get_value(), 0, "Ultimate runtime HIT does not regenerate spent meter")

    var timing := _battle()
    timing.fighter_a.meter.gain(100)
    _tick(timing, InputFrame.with_ultimate_press(1))
    for _i in range(49):
        _tick(timing)
    t.equal(timing.frame_number, 50, "Ultimate runtime timing reaches simulation F50 deterministically")
    t.equal(timing.fighter_a.move_runner.move_frame, 51, "Ultimate is still running final Recovery frame before simulation F51 resolves")
    t.equal(timing.fighter_a.move_runner.phase(), &"RECOVERY", "Ultimate runtime phase is Recovery on move frame 51")
    _tick(timing)
    t.equal(timing.frame_number, 51, "Ultimate completes its 51 occupied simulation frames")
    t.that(not timing.fighter_a.move_runner.is_running(), "Ultimate is no longer running after F51")
    _tick(timing, InputFrame.with_light_press(52))
    t.equal(timing.fighter_a.move_runner.current_move_id(), MoveIds.STAND_LIGHT, "Ultimate is actionable on simulation F52 through normal move-start path")

func _test_special_ground_air_and_whiff_rules() -> void:
    var ground := _battle()
    _start_lv1_special(ground)
    t.equal(ground.fighter_a.state_machine.state, FighterStateMachine.State.GROUND_ATTACK, "Minimum-charge release enters generic GROUND_ATTACK state")
    t.equal(ground.fighter_a.move_runner.current_move_id(), MoveIds.SPECIAL_NEUTRAL, "Minimum-charge release starts canonical Lv1 special_neutral")

    var whiff := _battle()
    _start_lv1_special(whiff)
    while whiff.fighter_a.move_runner.is_running():
        _tick(whiff)
    t.equal(whiff.fighter_a.state_machine.state, FighterStateMachine.State.IDLE, "Special whiff completes normal recovery and returns actionable ground state")
    t.equal(whiff.fighter_a.meter.get_value(), 0, "Special whiff neither costs nor gains meter")

    var air := _battle()
    _tick(air, InputFrame.new(1, 0, 1, 0, 0, 0))
    _tick(air, InputFrame.with_special_press(2))
    t.that(air.fighter_a.move_runner.current_move_id() != MoveIds.SPECIAL_NEUTRAL, "Air SPECIAL cannot start")
    t.equal(air.fighter_a.state_machine.state, FighterStateMachine.State.JUMP, "Air SPECIAL leaves fighter in Jump")

func _test_ultimate_meter_spend_and_legality() -> void:
    var insufficient := _battle()
    insufficient.fighter_a.meter.set_value(99)
    _tick(insufficient, InputFrame.with_ultimate_press(1))
    t.that(insufficient.fighter_a.move_runner.current_move_id() != MoveIds.ULTIMATE, "99 meter cannot start Ultimate")
    t.equal(insufficient.fighter_a.meter.get_value(), 99, "Failed Ultimate start leaves 99 meter unchanged")

    var exact := _battle()
    exact.fighter_a.meter.gain(100)
    _tick(exact, InputFrame.with_ultimate_press(1))
    t.equal(exact.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "100 meter starts Ultimate")
    t.equal(exact.fighter_a.meter.get_value(), 0, "Ultimate spends 100 immediately on successful start")
    for _i in range(8):
        _tick(exact)
    t.equal(exact.fighter_a.meter.get_value(), 0, "Whiffing Ultimate never refunds meter")

    var air := _battle()
    air.fighter_a.meter.gain(100)
    _tick(air, InputFrame.new(1, 0, 1, 0, 0, 0))
    _tick(air, InputFrame.with_ultimate_press(2))
    t.that(air.fighter_a.move_runner.current_move_id() != MoveIds.ULTIMATE, "Ultimate cannot air-start")
    t.equal(air.fighter_a.meter.get_value(), 100, "Rejected air Ultimate does not spend meter")

    var hitstun := _battle()
    hitstun.fighter_a.meter.gain(100)
    hitstun.fighter_a.combatant.hitstun_remaining = 3
    _tick(hitstun, InputFrame.with_ultimate_press(1))
    t.that(hitstun.fighter_a.move_runner.current_move_id() != MoveIds.ULTIMATE, "Ultimate cannot start during forced hit reaction")
    t.equal(hitstun.fighter_a.meter.get_value(), 100, "Forced-reaction Ultimate rejection does not spend meter")

func _test_guard_priority_and_throw_air_regression() -> void:
    var guard_special := _battle()
    _tick(guard_special, _guard_with_action(1, InputFrame.InputButton.SPECIAL))
    t.equal(guard_special.fighter_a.state_machine.state, FighterStateMachine.State.GUARD, "Held Guard has priority over buffered Special")
    t.that(not guard_special.fighter_a.move_runner.is_running(), "Guard does not bypass into Special")

    var guard_ultimate := _battle()
    guard_ultimate.fighter_a.meter.gain(100)
    _tick(guard_ultimate, _guard_with_action(1, InputFrame.InputButton.ULTIMATE))
    t.equal(guard_ultimate.fighter_a.state_machine.state, FighterStateMachine.State.GUARD, "Held Guard has priority over buffered Ultimate")
    t.equal(guard_ultimate.fighter_a.meter.get_value(), 100, "Guard-priority Ultimate does not spend meter")

    var throw_battle := _battle()
    _tick(throw_battle, InputFrame.with_heavy_press(1, 1))
    t.equal(throw_battle.fighter_a.move_runner.current_move_id(), MoveIds.GROUND_THROW, "Forward+Heavy still starts Throw after M3 parser changes")

    var heavy_battle := _battle()
    _tick(heavy_battle, InputFrame.with_heavy_press(1))
    t.equal(heavy_battle.fighter_a.move_runner.current_move_id(), MoveIds.STAND_HEAVY, "Neutral+Heavy still starts Stand Heavy")

    var air_light := _battle()
    _tick(air_light, InputFrame.new(1, 0, 1, 0, 0, 0))
    _tick(air_light, InputFrame.with_light_press(2))
    t.equal(air_light.fighter_a.move_runner.current_move_id(), MoveIds.AIR_ATTACK, "Air Light remains Air Attack")

    var air_heavy := _battle()
    _tick(air_heavy, InputFrame.new(1, 0, 1, 0, 0, 0))
    _tick(air_heavy, InputFrame.with_heavy_press(2, 1))
    t.equal(air_heavy.fighter_a.move_runner.current_move_id(), MoveIds.AIR_ATTACK, "Air Heavy remains same Air Attack and never Throw")
