# Responsibility: M6 Versus round lifecycle, KO/draw/score/post-round/reset/match-over integration tests.
class_name Milestone6RoundFlowTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var generic: CharacterData
var rush: CharacterData
var zone: CharacterData
var versus: MatchRulesData

func run_all() -> int:
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    versus = load("res://data/match_rules/versus_match_rules.tres") as MatchRulesData
    _test_initial_round_and_timer()
    _test_single_ko_post_round_exact_reset()
    _test_double_ko_draw()
    _test_round_reset_clears_runtime_and_preserves_projectile_serial()
    _test_round_wins_and_match_over_lock()
    _test_full_match_reset()
    _test_post_round_input_and_contact_suppression()
    _test_post_round_airborne_ko_settlement()
    _test_post_round_mirror_settlement_is_symmetric()
    print("\nM6 Round Flow tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData = null, b: CharacterData = null, rules: MatchRulesData = null) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(
        a if a != null else generic,
        b if b != null else rush,
        null,
        null,
        Vector2i(50000, BattleSimulation.GROUND_Y_UNITS),
        Vector2i(78000, BattleSimulation.GROUND_Y_UNITS),
        rules if rules != null else versus
    )
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _advance(battle: BattleSimulation, count: int) -> void:
    for _i in range(count):
        _tick(battle)

func _ko(fighter: Fighter) -> void:
    fighter.combatant.hp = 0
    fighter.combatant.is_ko = true

func _test_initial_round_and_timer() -> void:
    var battle := _battle()
    t.equal(battle.round_controller.state, RoundController.State.ROUND_ACTIVE, "New match starts ROUND_ACTIVE")
    t.equal(battle.round_controller.round_number, 1, "New match starts at Round 1")
    t.equal(battle.round_controller.p1_round_wins, 0, "P1 starts at zero round wins")
    t.equal(battle.round_controller.p2_round_wins, 0, "P2 starts at zero round wins")
    t.equal(battle.round_controller.round_timer_remaining_frames, versus.round_timer_frames, "Versus timer starts at configured deterministic duration")
    _tick(battle)
    t.equal(battle.round_controller.round_timer_remaining_frames, versus.round_timer_frames - 1, "One active non-hitstop simulation tick decrements timer exactly once")

func _test_single_ko_post_round_exact_reset() -> void:
    var battle := _battle()
    var configured_start_a := battle.configured_start_position(1)
    var configured_start_b := battle.configured_start_position(2)
    _ko(battle.fighter_b)
    _tick(battle)
    t.equal(battle.round_controller.state, RoundController.State.POST_ROUND, "P2 KO enters POST_ROUND")
    t.equal(battle.round_controller.round_result, RoundController.RoundResult.P1_WIN, "P2 KO awards P1 round result")
    t.equal(battle.round_controller.p1_round_wins, 1, "P1 receives exactly one round win")
    t.equal(battle.round_controller.post_round_remaining_frames, 90, "Round-ending tick preserves full 90F post-round countdown")
    _advance(battle, 89)
    t.equal(battle.round_controller.state, RoundController.State.POST_ROUND, "After 89 later ticks round remains POST_ROUND")
    t.equal(battle.round_controller.post_round_remaining_frames, 1, "Post-round countdown reaches 1 after 89 ticks")
    var frame_before_reset := battle.frame_number
    _tick(battle)
    t.equal(battle.round_controller.state, RoundController.State.ROUND_ACTIVE, "90th post-round tick starts next round")
    t.equal(battle.round_controller.round_number, 2, "Versus round number advances after post-round")
    t.equal(battle.frame_number, frame_before_reset + 1, "Global BattleSimulation frame remains monotonic across round reset")
    t.equal(battle.fighter_a.combatant.hp, 5000, "Next round restores P1 HP")
    t.equal(battle.fighter_b.combatant.hp, 5000, "Next round restores P2 HP")
    t.equal(battle.round_controller.round_timer_remaining_frames, versus.round_timer_frames, "Next round timer resets to configured duration")
    t.equal(battle.fighter_a.movement_motor.sim_position, configured_start_a, "Round reset restores configured P1 start")
    t.equal(battle.fighter_b.movement_motor.sim_position, configured_start_b, "Round reset restores configured P2 start")

func _test_double_ko_draw() -> void:
    var battle := _battle()
    _ko(battle.fighter_a)
    _ko(battle.fighter_b)
    _tick(battle)
    t.equal(battle.round_controller.round_result, RoundController.RoundResult.DRAW, "Same authoritative tick double KO is DRAW")
    t.equal(battle.round_controller.p1_round_wins, 0, "Double KO does not increment P1 wins")
    t.equal(battle.round_controller.p2_round_wins, 0, "Double KO does not increment P2 wins")
    _advance(battle, 90)
    t.equal(battle.round_controller.round_number, 2, "Draw still advances Versus round number")

func _test_round_reset_clears_runtime_and_preserves_projectile_serial() -> void:
    var battle := _battle(zone, generic)
    var configured_start_a := battle.configured_start_position(1)
    var special := battle.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, special.projectile_spawns[0])
    battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, special.projectile_spawns[0])
    var serial_before := battle.projectile_system.next_projectile_instance_serial
    battle.fighter_a.meter.set_value(87)
    battle.fighter_a.input_history.push(InputFrame.new(1, 1, 0, 0, 0, 0))
    battle.fighter_a.input_buffer.buffer_intent(ActionIntent.from_input_frame(InputFrame.with_special_press(2), battle.fighter_a.movement_motor.facing, InputFrame.InputButton.SPECIAL))
    battle.fighter_a.move_runner.start_move(battle.fighter_a.move_registry.get_move(MoveIds.STAND_LIGHT))
    battle.fighter_a.hitbox_owner.begin_attack_instance(battle.fighter_a.move_runner.attack_instance_id)
    battle.fighter_a.movement_motor.sim_position.x = 64000
    _ko(battle.fighter_b)
    _tick(battle)
    t.equal(battle.projectile_system.active_count(), 0, "Round-ending tick clears every active temporary projectile")
    t.equal(battle.projectile_system.next_projectile_instance_serial, serial_before, "Round cleanup preserves monotonic projectile serial")
    _advance(battle, 90)
    t.equal(battle.fighter_a.meter.get_value(), 0, "Versus prototype resets meter each round")
    t.equal(battle.fighter_a.input_history.count(), 0, "Round reset clears InputHistory")
    t.that(not battle.fighter_a.input_buffer.has_pending(battle.frame_number), "Round reset clears InputBuffer")
    t.that(not battle.fighter_a.move_runner.is_running(), "Round reset returns MoveRunner to idle")
    t.equal(battle.fighter_a.movement_motor.sim_position, configured_start_a, "Round reset restores configured P1 start position")
    t.equal(battle.fighter_a.movement_motor.facing, 1, "Round reset restores canonical P1 facing")
    t.equal(battle.fighter_b.movement_motor.facing, -1, "Round reset restores canonical P2 facing")
    t.equal(battle.projectile_system.next_projectile_instance_serial, serial_before, "Round reset still does not rewind projectile instance serial")

func _test_round_wins_and_match_over_lock() -> void:
    var battle := _battle()
    _ko(battle.fighter_b)
    _tick(battle)
    _advance(battle, 90)
    _ko(battle.fighter_b)
    _tick(battle)
    t.equal(battle.round_controller.p1_round_wins, 2, "Second P1 round win reaches rounds_to_win")
    t.equal(battle.round_controller.pending_match_winner, RoundController.Participant.P1, "Match winner remains pending through full post-round period")
    _advance(battle, 90)
    t.equal(battle.round_controller.state, RoundController.State.MATCH_OVER, "Second winning round reaches MATCH_OVER only after post-round")
    t.equal(battle.round_controller.match_winner, RoundController.Participant.P1, "MATCH_OVER stores participant winner P1")
    var frozen_position := battle.fighter_a.movement_motor.sim_position
    var frozen_frame := battle.frame_number
    _tick(battle, InputFrame.with_light_press(frozen_frame + 1), InputFrame.with_special_press(frozen_frame + 1))
    t.equal(battle.frame_number, frozen_frame + 1, "MATCH_OVER tick keeps global simulation frame monotonic")
    t.equal(battle.fighter_a.movement_motor.sim_position, frozen_position, "MATCH_OVER suppresses gameplay movement/action state")
    t.that(not battle.fighter_a.move_runner.is_running(), "MATCH_OVER cannot start a new Fighter move")

func _test_full_match_reset() -> void:
    var battle := _battle(zone, generic)
    var configured_start_a := battle.configured_start_position(1)
    var configured_start_b := battle.configured_start_position(2)
    var character_a := battle.fighter_a.data
    var character_b := battle.fighter_b.data
    var special := battle.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, special.projectile_spawns[0])
    _advance(battle, 4)
    battle.round_controller.p1_round_wins = 1
    battle.fighter_a.meter.set_value(66)
    battle.reset_full_match()
    t.equal(battle.frame_number, 0, "Explicit full match reset resets global simulation frame")
    t.equal(battle.round_controller.round_number, 1, "Full reset returns Round 1")
    t.equal(battle.round_controller.p1_round_wins, 0, "Full reset clears round score")
    t.equal(battle.projectile_system.active_count(), 0, "Full reset clears active projectiles")
    t.equal(battle.projectile_system.next_projectile_instance_serial, ProjectileSystem.INITIAL_INSTANCE_SERIAL, "Full reset resets projectile serial")
    t.equal(battle.fighter_a.meter.get_value(), 0, "Full reset clears meter")
    t.equal(battle.fighter_a.movement_motor.sim_position, configured_start_a, "Full reset restores configured P1 start")
    t.equal(battle.fighter_b.movement_motor.sim_position, configured_start_b, "Full reset restores configured P2 start")
    t.that(battle.fighter_a.data == character_a and battle.fighter_b.data == character_b, "Full reset preserves configured CharacterData identity")

func _test_post_round_input_and_contact_suppression() -> void:
    var battle := _battle(generic, rush)
    _ko(battle.fighter_b)
    _tick(battle)
    battle.fighter_b.combatant.hp = 100
    var hp_before := battle.fighter_b.combatant.hp
    var frame := battle.frame_number + 1
    _tick(battle, InputFrame.with_light_press(frame), InputFrame.with_special_press(frame))
    t.equal(battle.fighter_b.combatant.hp, hp_before, "POST_ROUND builds no new strike/projectile/throw contacts")
    t.that(not battle.fighter_a.move_runner.is_running(), "POST_ROUND player input cannot start new offense")

func _test_post_round_airborne_ko_settlement() -> void:
    var battle := _battle()
    _ko(battle.fighter_b)
    battle.fighter_b.movement_motor.sim_position.y = BattleSimulation.GROUND_Y_UNITS - 2000
    battle.fighter_b.movement_motor.velocity_units.y = 400
    _tick(battle)
    var y_before := battle.fighter_b.movement_motor.sim_position.y
    _tick(battle)
    t.that(battle.fighter_b.movement_motor.sim_position.y > y_before, "Airborne KO continues gravity/landing settlement during POST_ROUND")
    t.that(battle.fighter_b.combatant.is_ko, "Airborne POST_ROUND settlement preserves KO until reset")


# M7 prior-milestone regression: M6 accidentally ticked P1 movement twice during POST_ROUND.
func _test_post_round_mirror_settlement_is_symmetric() -> void:
    var battle := _battle(generic, generic)
    _ko(battle.fighter_a)
    _ko(battle.fighter_b)
    battle.fighter_a.movement_motor.sim_position.y = BattleSimulation.GROUND_Y_UNITS - 2000
    battle.fighter_b.movement_motor.sim_position.y = BattleSimulation.GROUND_Y_UNITS - 2000
    battle.fighter_a.movement_motor.velocity_units.y = 400
    battle.fighter_b.movement_motor.velocity_units.y = 400
    _tick(battle)
    t.equal(battle.round_controller.state, RoundController.State.POST_ROUND, "Mirror double-KO enters POST_ROUND for symmetric settlement regression")
    _tick(battle)
    t.equal(battle.fighter_a.movement_motor.sim_position.y, battle.fighter_b.movement_motor.sim_position.y, "POST_ROUND mirror Fighters receive exactly one movement settlement tick each")
    t.equal(battle.fighter_a.movement_motor.velocity_units.y, battle.fighter_b.movement_motor.velocity_units.y, "POST_ROUND mirror Fighter gravity/velocity settlement remains symmetric")
