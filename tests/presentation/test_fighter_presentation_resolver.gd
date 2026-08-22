# M7 authoritative state/move -> visual resolver and render mapping tests.
class_name FighterPresentationResolverTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var presentation: CharacterPresentationData
var fighter: Fighter

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    presentation = load("res://presentation/characters/generic_fighter_presentation.tres") as CharacterPresentationData
    fighter = Fighter.new()
    fighter.configure(1, generic, Vector2i(50000, 56000), 8000, 120000, 56000)
    _test_state_resolution()
    _test_move_resolution()
    _test_unit_mapping_and_facing_visual()
    print("\nM7 FighterPresentationResolver tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _expect_state(state_value: int, expected: StringName) -> void:
    fighter.state_machine.state = state_value
    t.equal(FighterPresentationResolver.resolve_animation(fighter, presentation), expected, "%s resolves to %s" % [FighterStateMachine.State.keys()[state_value], String(expected)])

func _test_state_resolution() -> void:
    _expect_state(FighterStateMachine.State.IDLE, &"idle")
    _expect_state(FighterStateMachine.State.WALK_FORWARD, &"walk_forward")
    _expect_state(FighterStateMachine.State.WALK_BACK, &"walk_back")
    _expect_state(FighterStateMachine.State.CROUCH, &"crouch")
    _expect_state(FighterStateMachine.State.JUMP, &"jump")
    _expect_state(FighterStateMachine.State.LANDING, &"landing")
    fighter.state_machine.state = FighterStateMachine.State.GUARD
    fighter.state_machine.guard_posture = FighterStateMachine.GuardPosture.STANDING
    t.equal(FighterPresentationResolver.resolve_animation(fighter, presentation), &"guard_stand", "Standing Guard resolves from authoritative GuardPosture")
    fighter.state_machine.guard_posture = FighterStateMachine.GuardPosture.CROUCHING
    t.equal(FighterPresentationResolver.resolve_animation(fighter, presentation), &"guard_crouch", "Crouching Guard resolves from authoritative GuardPosture")
    _expect_state(FighterStateMachine.State.HITSTUN, &"hitstun")
    _expect_state(FighterStateMachine.State.BLOCKSTUN, &"blockstun")
    _expect_state(FighterStateMachine.State.THROWN, &"thrown")
    _expect_state(FighterStateMachine.State.KNOCKDOWN, &"knockdown")
    _expect_state(FighterStateMachine.State.GETUP, &"getup")
    _expect_state(FighterStateMachine.State.KO, &"ko")
    _expect_state(FighterStateMachine.State.DASH_FORWARD, &"dash_forward")
    _expect_state(FighterStateMachine.State.BACKSTEP, &"backstep")

func _test_move_resolution() -> void:
    fighter.move_runner.reset_runtime(true)
    fighter.state_machine.state = FighterStateMachine.State.GROUND_ATTACK
    var light := fighter.move_registry.get_move(&"stand_light")
    fighter.move_runner.start_move(light)
    t.equal(FighterPresentationResolver.resolve_animation(fighter, presentation), &"stand_light", "Current Stand Light Move ID resolves through presentation Move binding")
    fighter.move_runner.interrupt()
    var special := fighter.move_registry.get_move(&"special_neutral")
    fighter.move_runner.start_move(special)
    t.equal(FighterPresentationResolver.resolve_animation(fighter, presentation), &"special_neutral", "Salad Cat Special keeps canonical runtime animation key")
    fighter.move_runner.interrupt()
    var ultimate := fighter.move_registry.get_move(&"ultimate")
    fighter.move_runner.start_move(ultimate)
    t.equal(FighterPresentationResolver.resolve_animation(fighter, presentation), &"ultimate", "Salad Cat Ultimate keeps canonical runtime animation key without timing authority")

func _test_unit_mapping_and_facing_visual() -> void:
    t.equal(SimulationRenderConverter.to_pixels(Vector2i(12300, 56000)), Vector2(123, 560), "100 simulation units map to exactly one presentation pixel")
    var visual := GreyboxFighterVisual.new()
    visual.set_character_presentation_data(presentation)
    visual.set_screen_position(Vector2(500, 560))
    visual.set_facing(-1)
    t.equal(visual.position, Vector2(500, 560), "Visual screen position is a one-way render value")
    t.that(visual.scale.x < 0.0, "Facing -1 mirrors presentation scale only")
    visual.free()
