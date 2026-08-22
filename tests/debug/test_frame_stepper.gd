# Responsibility: FrameStepper exact simulation-frame control regression tests.
class_name FrameStepperTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    _test_pause_and_exact_advance()
    _test_round_timer_advances_only_consumed_simulation_ticks()
    print("\nFrameStepper tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _test_pause_and_exact_advance() -> void:
    var clock := SimulationClock.new()
    var stepper := FrameStepper.new()
    stepper.toggle_pause(clock)
    t.that(stepper.paused, "F3 semantics pause simulation clock while render may continue")
    t.equal(stepper.consume_ticks(clock, 1.0), 0, "Paused FrameStepper emits zero render-delta simulation ticks")
    stepper.request_advance(1, clock)
    t.equal(stepper.consume_ticks(clock, 0.0), 1, "F4 advances exactly 1 simulation frame")
    t.equal(stepper.consume_ticks(clock, 0.0), 0, "Single-step request is consumed exactly once")
    stepper.request_advance(5, clock)
    t.equal(stepper.consume_ticks(clock, 0.0), 5, "F5 advances exactly 5 simulation frames")
    stepper.toggle_pause(clock)
    t.that(not stepper.paused, "F3 semantics resume simulation")

func _test_round_timer_advances_only_consumed_simulation_ticks() -> void:
    var generic := load("res://data/characters/generic_fighter.tres") as CharacterData
    var rules := MatchRulesData.versus_defaults()
    rules.round_timer_frames = 100
    var battle := BattleSimulation.new()
    battle.configure(generic, generic, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(78000, BattleSimulation.GROUND_Y_UNITS), rules)
    var clock := SimulationClock.new()
    var stepper := FrameStepper.new()
    stepper.toggle_pause(clock)
    var before := battle.round_controller.round_timer_remaining_frames
    for _tick in range(stepper.consume_ticks(clock, 1.0)):
        battle.simulate_frame(InputFrame.neutral(battle.frame_number + 1), InputFrame.neutral(battle.frame_number + 1))
    t.equal(battle.round_controller.round_timer_remaining_frames, before, "Paused FrameStepper does not advance deterministic Round timer")
    stepper.request_advance(1, clock)
    for _tick in range(stepper.consume_ticks(clock, 0.0)):
        battle.simulate_frame(InputFrame.neutral(battle.frame_number + 1), InputFrame.neutral(battle.frame_number + 1))
    t.equal(battle.round_controller.round_timer_remaining_frames, before - 1, "F4 one-step advances Round timer by exactly one active non-hitstop tick")
    stepper.request_advance(5, clock)
    for _tick in range(stepper.consume_ticks(clock, 0.0)):
        battle.simulate_frame(InputFrame.neutral(battle.frame_number + 1), InputFrame.neutral(battle.frame_number + 1))
    t.equal(battle.round_controller.round_timer_remaining_frames, before - 6, "F5 five-step advances Round timer by exactly five additional active ticks")
