# Responsibility: M5 same-frame projectile/melee build-resolve-apply trade and meter authority proof.
class_name Milestone5ProjectileTradeTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()
var zone: CharacterData
var rush: CharacterData

func run_all() -> int:
    zone = load("res://data/characters/zone_fighter.tres") as CharacterData
    rush = load("res://data/characters/rush_grappler.tres") as CharacterData
    _test_projectile_and_melee_same_frame_trade()
    _test_same_frame_lethal_projectile_outcome_survives_owner_ko()
    print("\nM5 Projectile Trade tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle() -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(zone, rush, null, null, Vector2i(50000, BattleSimulation.GROUND_Y_UNITS), Vector2i(57000, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _setup_trade(battle: BattleSimulation) -> ProjectileRuntime:
    var special := battle.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    var projectile := battle.projectile_system.spawn_from_descriptor(battle.fighter_a, MoveIds.SPECIAL_NEUTRAL, 0, special.projectile_spawns[0])
    # After BattleSimulation advances it by +800 this tick, center lands inside Rush hurtbox.
    projectile.position_units = Vector2i(50100, BattleSimulation.GROUND_Y_UNITS - 70)
    var rush_light := battle.fighter_b.move_registry.get_move(MoveIds.STAND_LIGHT)
    battle.fighter_b.move_runner.start_move(rush_light)
    battle.fighter_b.hitbox_owner.begin_attack_instance(battle.fighter_b.move_runner.attack_instance_id)
    battle.fighter_b.move_runner.move_frame = rush_light.first_active_frame()
    battle.fighter_b.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    return projectile

func _test_projectile_and_melee_same_frame_trade() -> void:
    var battle := _battle()
    _setup_trade(battle)
    battle.simulate_frame(InputFrame.neutral(1), InputFrame.neutral(1))
    t.equal(battle.fighter_a.combatant.hp, 4955, "Rush active Light applies 45 damage to Zone in trade")
    t.equal(battle.fighter_b.combatant.hp, 4920, "Zone projectile applies 80 damage to Rush in same frame")
    t.equal(battle.fighter_a.meter.get_value(), 70, "Zone gets projectile +14 meter in trade")
    t.equal(battle.fighter_b.meter.get_value(), 35, "Rush gets Light +7 meter in trade")
    t.equal(battle.projectile_system.active_count(), 0, "Resolved trade projectile despawns after apply phase")

func _test_same_frame_lethal_projectile_outcome_survives_owner_ko() -> void:
    var battle := _battle()
    _setup_trade(battle)
    battle.fighter_a.combatant.hp = 40
    battle.fighter_b.combatant.hp = 70
    battle.simulate_frame(InputFrame.neutral(1), InputFrame.neutral(1))
    t.that(battle.fighter_a.combatant.is_ko, "Rush melee can KO projectile owner in same frame")
    t.that(battle.fighter_b.combatant.is_ko, "Already-built projectile outcome still KOs Rush in same frame")
    t.equal(battle.projectile_system.active_count(), 0, "Owner projectile cleanup occurs after same-frame outcomes apply")
