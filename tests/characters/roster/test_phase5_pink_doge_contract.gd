# Phase 5 real-runtime contract scenarios for Pink Star and Doge only.
class_name Phase5PinkDogeContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")
const FINISHER_IDS: Array[StringName] = [&"pink_true_finisher_2", &"pink_true_finisher_3", &"pink_true_finisher_4", &"pink_true_finisher_5"]
const FINISHER_DAMAGE: Array[int] = [105, 135, 165, 195]

var t = ASSERT_HELPER.new()
var pink: CharacterData
var doge: CharacterData
var generic: CharacterData

func run_all() -> int:
    pink = RosterRegistry.character_by_id(&"pink_star")
    doge = RosterRegistry.character_by_id(&"doge")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_pink_entry_costs_and_dash_cancel()
    _test_pink_one_star_rejection()
    _test_pink_finisher_tiers_hit_block_whiff()
    _test_pink_hit_confirm_and_block_rejection()
    _test_pink_collapse()
    _test_pink_snapshot_hash()
    _test_doge_lv1_lv2_no_armor()
    _test_doge_lv3_one_strike_only()
    _test_doge_throw_charge_projectile_and_risk()
    _test_doge_armor_snapshot()
    print("\nPhase 5 Pink/Doge contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData, ax: int = 50000, bx: int = 57000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _guard(frame: int) -> InputFrame:
    return InputFrame.new(frame, 0, 0, InputFrame.InputButton.GUARD, 0, 0)

func _true_face(battle: BattleSimulation, stars: int) -> void:
    t.that(battle.fighter_a.mode.enter(&"true_face", -1, battle.frame_number), "Pink enters authored True Face setup")
    t.that(battle.fighter_a.resources.set_value(&"face_actions", stars), "Pink authoritative Stars setup succeeds")

func _start_move(fighter: Fighter, move_id: StringName, frame: int = -1) -> MoveData:
    var move := fighter.move_registry.get_move(move_id)
    fighter.move_runner.interrupt()
    t.that(move != null and fighter.move_runner.start_move(move), "%s starts through real MoveRunner" % String(move_id))
    fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
    fighter.mechanics_runtime.begin_move_defenses(move, fighter.move_runner.attack_instance_id)
    fighter.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    if frame > 0:
        fighter.move_runner.move_frame = frame
    return move

func _test_pink_entry_costs_and_dash_cancel() -> void:
    var entry := _battle(pink, generic, 50000, 100000)
    entry.fighter_a.meter.set_value(100)
    _tick(entry, InputFrame.with_ultimate_press(1))
    t.equal(entry.fighter_a.get_active_mode_id(), &"true_face", "Base Ultimate enters True Face")
    t.equal(entry.fighter_a.get_resource_value(&"face_actions"), 5, "Base Ultimate establishes five Stars")

    var heavy := _battle(pink, generic, 50000, 100000)
    _true_face(heavy, 5)
    _tick(heavy, InputFrame.with_heavy_press(1))
    t.equal(heavy.fighter_a.move_runner.current_move_id(), &"pink_true_heavy", "True Face Heavy resolves generic mode override")
    t.equal(heavy.fighter_a.get_resource_value(&"face_actions"), 4, "True Heavy activation costs exactly one Star")

    var special := _battle(pink, generic, 50000, 100000)
    _true_face(special, 5)
    _tick(special, InputFrame.with_special_press(1))
    _tick(special, InputFrame.new(2, 0, 0, InputFrame.InputButton.SPECIAL, 0, 0))
    _tick(special, InputFrame.new(3, 0, 0, 0, 0, InputFrame.InputButton.SPECIAL))
    t.equal(special.fighter_a.move_runner.current_move_id(), &"pink_true_scream_l1", "True Special releases through generic ChargeSpecialData")
    t.equal(special.fighter_a.get_resource_value(&"face_actions"), 4, "True Special activation costs exactly one Star")

    var dash := _battle(pink, generic, 50000, 100000)
    _true_face(dash, 5)
    var light := _start_move(dash.fighter_a, &"pink_true_light", 5)
    dash.fighter_a.move_runner.connected_hit = true
    dash.fighter_a.combo_scaling.register_confirmed_hit(dash.fighter_b.fighter_id, 36, true, false)
    dash.fighter_b.combatant.hitstun_remaining = 12
    _tick(dash, InputFrame.new(1, 1, 0, 0, 0, 0))
    _tick(dash, InputFrame.neutral(2))
    _tick(dash, InputFrame.new(3, 1, 0, 0, 0, 0))
    t.equal(dash.fighter_a.state_machine.state, FighterStateMachine.State.DASH_FORWARD, "First same-combo Dash Cancel executes")
    t.equal(dash.fighter_a.get_resource_value(&"face_actions"), 4, "First Dash Cancel spends one Star")
    t.equal(dash.fighter_a.combo_scaling.dash_cancel_count, 1, "First Dash Cancel consumes generic combo budget")
    dash.fighter_a.state_machine.transition_to(FighterStateMachine.State.IDLE)
    dash.fighter_a.move_runner.interrupt()
    dash.fighter_a.move_runner.start_move(light)
    dash.fighter_a.hitbox_owner.begin_attack_instance(dash.fighter_a.move_runner.attack_instance_id)
    dash.fighter_a.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
    dash.fighter_a.move_runner.move_frame = 5
    dash.fighter_a.move_runner.connected_hit = true
    dash.fighter_b.combatant.hitstun_remaining = 12
    var before_second := dash.fighter_a.get_resource_value(&"face_actions")
    var f := dash.frame_number
    _tick(dash, InputFrame.new(f + 1, 1, 0, 0, 0, 0))
    _tick(dash, InputFrame.neutral(f + 2))
    _tick(dash, InputFrame.new(f + 3, 1, 0, 0, 0, 0))
    t.that(dash.fighter_a.state_machine.state != FighterStateMachine.State.DASH_FORWARD, "Second same-combo Dash Cancel is rejected")
    t.equal(dash.fighter_a.get_resource_value(&"face_actions"), before_second, "Rejected second Dash Cancel spends zero Stars")

func _test_pink_one_star_rejection() -> void:
    var battle := _battle(pink, generic, 50000, 100000)
    _true_face(battle, 1)
    _tick(battle, InputFrame.with_ultimate_press(1))
    t.equal(battle.fighter_a.get_resource_value(&"face_actions"), 1, "One-Star Finisher attempt spends zero")
    t.equal(battle.fighter_a.get_active_mode_id(), &"true_face", "One-Star Finisher attempt preserves True Face")
    t.that(not battle.fighter_a.move_runner.is_running(), "One-Star Finisher attempt starts no move")

func _test_pink_finisher_tiers_hit_block_whiff() -> void:
    for index in range(FINISHER_IDS.size()):
        var stars := index + 2
        var battle := _battle(pink, generic)
        _true_face(battle, stars)
        _tick(battle, InputFrame.with_ultimate_press(1))
        var move := battle.fighter_a.move_registry.get_move(FINISHER_IDS[index])
        t.equal(battle.fighter_a.move_runner.current_move_id(), FINISHER_IDS[index], "%d-Star raw Ultimate selects authored Finisher tier" % stars)
        t.equal(battle.fighter_a.get_resource_value(&"face_actions"), 0, "%d-Star Finisher consumes all Stars on activation" % stars)
        t.equal(move.damage, FINISHER_DAMAGE[index], "%d-Star Finisher authored raw damage tier" % stars)
        t.equal(move.hit_level, MoveData.HitLevel.MID, "%d-Star Finisher is MID" % stars)
        battle.fighter_a.move_runner.move_frame = move.first_active_frame()
        var hp_before := battle.fighter_b.combatant.hp
        _tick(battle)
        t.equal(hp_before - battle.fighter_b.combatant.hp, FINISHER_DAMAGE[index], "%d-Star Finisher deals authored pre-combo damage in real simulation" % stars)
        t.that(battle.fighter_b.state_machine.pending_knockdown_frames > 0, "%d-Star Finisher schedules Hard KD" % stars)
        t.equal(battle.fighter_a.get_active_mode_id(), &"", "%d-Star Finisher leaves True Face")

    var blocked := _battle(pink, generic)
    _true_face(blocked, 2)
    _tick(blocked, InputFrame.with_ultimate_press(1), _guard(1))
    var block_move := blocked.fighter_a.move_registry.get_move(&"pink_true_finisher_2")
    blocked.fighter_a.move_runner.move_frame = block_move.first_active_frame()
    var block_hp := blocked.fighter_b.combatant.hp
    _tick(blocked, null, _guard(2))
    t.equal(blocked.fighter_b.combatant.hp, block_hp, "Pink Finisher is blockable")
    t.equal(blocked.fighter_b.combatant.last_result_type, HitResult.ResultType.BLOCK, "Pink Finisher resolves canonical BLOCK")
    t.equal(FrameAdvantageCalculator.on_block(block_move), -12, "Pink Finisher authored block result is -12")

    var whiff := _battle(pink, generic, 50000, 110000)
    _true_face(whiff, 2)
    _tick(whiff, InputFrame.with_ultimate_press(1))
    var whiff_move := whiff.fighter_a.move_registry.get_move(&"pink_true_finisher_2")
    whiff.fighter_a.move_runner.move_frame = whiff_move.last_active_frame() + 1
    _tick(whiff)
    t.equal(whiff_move.recovery_frames, 34, "Pink Finisher has authored 34F whiff recovery")
    t.that(whiff.fighter_a.move_runner.is_running() and whiff.fighter_a.move_runner.phase() == &"RECOVERY", "Whiffed Pink Finisher remains committed in recovery")

    var interrupted := _battle(pink, generic)
    _true_face(interrupted, 4)
    _tick(interrupted, InputFrame.with_ultimate_press(1))
    var counterattack := _start_move(interrupted.fighter_b, MoveIds.STAND_LIGHT)
    interrupted.fighter_b.move_runner.move_frame = counterattack.first_active_frame()
    _tick(interrupted)
    t.equal(interrupted.fighter_a.get_resource_value(&"face_actions"), 0, "Interrupted legal Finisher receives no Star refund")
    t.equal(interrupted.fighter_a.get_active_mode_id(), &"", "Interrupted legal Finisher remains outside True Face")

func _test_pink_hit_confirm_and_block_rejection() -> void:
    var heavy_hit := _battle(pink, generic)
    _true_face(heavy_hit, 3)
    _tick(heavy_hit, InputFrame.with_heavy_press(1))
    var heavy_move := heavy_hit.fighter_a.move_registry.get_move(&"pink_true_heavy")
    heavy_hit.fighter_a.move_runner.move_frame = heavy_move.first_active_frame()
    _tick(heavy_hit)
    heavy_hit.fighter_a.combatant.hitstop_remaining = 0
    heavy_hit.fighter_a.move_runner.move_frame = 12
    _tick(heavy_hit, InputFrame.with_ultimate_press(3))
    t.equal(heavy_hit.fighter_a.move_runner.current_move_id(), &"pink_true_finisher_2", "True Heavy HIT cancels into resource-tier Finisher")

    var heavy_block := _battle(pink, generic)
    _true_face(heavy_block, 3)
    _tick(heavy_block, InputFrame.with_heavy_press(1), _guard(1))
    var blocked_heavy := heavy_block.fighter_a.move_registry.get_move(&"pink_true_heavy")
    heavy_block.fighter_a.move_runner.move_frame = blocked_heavy.first_active_frame()
    _tick(heavy_block, null, _guard(2))
    heavy_block.fighter_a.combatant.hitstop_remaining = 0
    heavy_block.fighter_a.move_runner.move_frame = 12
    var stars_before := heavy_block.fighter_a.get_resource_value(&"face_actions")
    _tick(heavy_block, InputFrame.with_ultimate_press(3), _guard(3))
    t.equal(heavy_block.fighter_a.move_runner.current_move_id(), &"pink_true_heavy", "True Heavy BLOCK cannot protected-cancel into Finisher")
    t.equal(heavy_block.fighter_a.get_resource_value(&"face_actions"), stars_before, "Rejected Heavy block-confirm spends zero Stars")

    var special_hit := _battle(pink, generic)
    _true_face(special_hit, 3)
    special_hit.fighter_a.resources.spend(&"face_actions", 1)
    var scream := _start_move(special_hit.fighter_a, &"pink_true_scream_l1")
    special_hit.fighter_a.move_runner.move_frame = scream.first_active_frame()
    _tick(special_hit)
    special_hit.fighter_a.combatant.hitstop_remaining = 0
    special_hit.fighter_a.move_runner.move_frame = 9
    _tick(special_hit, InputFrame.with_ultimate_press(2))
    t.equal(special_hit.fighter_a.move_runner.current_move_id(), &"pink_true_finisher_2", "True Special HIT cancels into resource-tier Finisher")

    var special_block := _battle(pink, generic)
    _true_face(special_block, 3)
    special_block.fighter_a.resources.spend(&"face_actions", 1)
    var blocked_scream := _start_move(special_block.fighter_a, &"pink_true_scream_l1")
    special_block.fighter_a.move_runner.move_frame = blocked_scream.first_active_frame()
    _tick(special_block, null, _guard(1))
    special_block.fighter_a.combatant.hitstop_remaining = 0
    special_block.fighter_a.move_runner.move_frame = 9
    _tick(special_block, InputFrame.with_ultimate_press(2), _guard(2))
    t.equal(special_block.fighter_a.move_runner.current_move_id(), &"pink_true_scream_l1", "True Special BLOCK cannot protected-cancel into Finisher")

func _test_pink_collapse() -> void:
    var battle := _battle(pink, generic, 50000, 100000)
    _true_face(battle, 1)
    _tick(battle, InputFrame.with_heavy_press(1))
    t.equal(battle.fighter_a.get_resource_value(&"face_actions"), 0, "Ordinary True action can exhaust final Star")
    t.equal(battle.fighter_a.get_active_mode_id(), &"", "Zero-Star ordinary exhaustion still collapses to Base")

func _test_pink_snapshot_hash() -> void:
    var battle := _battle(pink, generic)
    _true_face(battle, 3)
    battle.fighter_a.combo_scaling.dash_cancel_count = 1
    var snapshot := battle.capture_state()
    _tick(battle, InputFrame.with_ultimate_press(1))
    var move := battle.fighter_a.move_registry.get_move(&"pink_true_finisher_3")
    battle.fighter_a.move_runner.move_frame = move.first_active_frame()
    _tick(battle)
    var expected_hash := battle.state_signature()
    var expected_hp := battle.fighter_b.combatant.hp
    t.that(battle.restore_state(snapshot), "Pre-Finisher snapshot restores")
    _tick(battle, InputFrame.with_ultimate_press(1))
    battle.fighter_a.move_runner.move_frame = move.first_active_frame()
    _tick(battle)
    t.equal(battle.fighter_b.combatant.hp, expected_hp, "Restored Finisher reproduces identical damage result")
    t.equal(battle.state_signature(), expected_hash, "Restored Finisher reproduces identical authoritative hash")

func _test_doge_lv1_lv2_no_armor() -> void:
    for move_id: StringName in [&"doge_rush_l1", &"doge_rush_l2"]:
        var battle := _battle(generic, doge)
        var rush := _start_move(battle.fighter_b, move_id)
        battle.fighter_b.move_runner.move_frame = rush.first_active_frame()
        var light := _start_move(battle.fighter_a, MoveIds.STAND_LIGHT)
        battle.fighter_a.move_runner.move_frame = light.first_active_frame()
        var hp_before := battle.fighter_b.combatant.hp
        _tick(battle)
        t.that(battle.fighter_b.combatant.hp < hp_before, "%s takes real strike damage" % String(move_id))
        t.equal(battle.fighter_b.combatant.last_result_type, HitResult.ResultType.HIT, "%s has no strike armor" % String(move_id))
        t.that(not battle.fighter_b.move_runner.is_running(), "%s is interrupted by strike" % String(move_id))

func _test_doge_lv3_one_strike_only() -> void:
    var battle := _battle(generic, doge)
    var rush := _start_move(battle.fighter_b, &"doge_rush_l3", 7)
    var light := _start_move(battle.fighter_a, MoveIds.STAND_LIGHT)
    battle.fighter_a.move_runner.move_frame = light.first_active_frame()
    _tick(battle)
    t.equal(battle.fighter_b.combatant.last_result_type, HitResult.ResultType.ARMOR, "Doge Lv3 first valid strike resolves ARMOR")
    t.equal(battle.fighter_b.mechanics_runtime.armor_remaining_hits, 0, "Doge Lv3 consumes its only armor hit")
    t.equal(battle.fighter_b.move_runner.current_move_id(), &"doge_rush_l3", "First armored strike does not interrupt Lv3 Rush")
    battle.fighter_a.combatant.hitstop_remaining = 0
    battle.fighter_b.combatant.hitstop_remaining = 0
    light = _start_move(battle.fighter_a, MoveIds.STAND_LIGHT)
    battle.fighter_a.move_runner.move_frame = light.first_active_frame()
    battle.fighter_b.move_runner.move_frame = 8
    _tick(battle)
    t.equal(battle.fighter_b.combatant.last_result_type, HitResult.ResultType.HIT, "Second strike hits after Lv3 armor is consumed")
    t.that(not battle.fighter_b.move_runner.is_running(), "Second strike interrupts Lv3 Rush")

func _test_doge_throw_charge_projectile_and_risk() -> void:
    var thrown := _battle(generic, doge, 50000, 55000)
    _start_move(thrown.fighter_b, &"doge_rush_l3", 7)
    var throw_move := _start_move(thrown.fighter_a, MoveIds.GROUND_THROW)
    thrown.fighter_a.state_machine.transition_to(FighterStateMachine.State.THROW)
    thrown.fighter_a.move_runner.move_frame = throw_move.first_active_frame()
    var contact := thrown.throw_system.build_throw_contact(thrown.fighter_a, thrown.fighter_b)
    t.that(contact != null, "Real ThrowSystem overlaps armored Lv3 Doge")
    if contact != null:
        var result := thrown.combat_resolver.resolve_confirmed_throw(contact, thrown.fighter_a, thrown.fighter_b)
        thrown.combat_resolver.apply_throw_result(1, result, thrown.fighter_a, thrown.fighter_b, [])
        t.equal(thrown.fighter_b.state_machine.state, FighterStateMachine.State.THROWN, "Throw beats Lv3 strike armor")
        t.equal(thrown.fighter_b.mechanics_runtime.armor_remaining_hits, 0, "Throw clears remaining armor state")

    var charge := _battle(generic, doge)
    _tick(charge, null, InputFrame.with_special_press(1))
    t.equal(charge.fighter_b.state_machine.state, FighterStateMachine.State.CHARGE, "Doge enters real charge state")
    var attack := _start_move(charge.fighter_a, MoveIds.STAND_LIGHT)
    charge.fighter_a.move_runner.move_frame = attack.first_active_frame()
    var charge_hp := charge.fighter_b.combatant.hp
    _tick(charge, null, InputFrame.new(2, 0, 0, InputFrame.InputButton.SPECIAL, 0, 0))
    t.that(charge.fighter_b.combatant.hp < charge_hp and charge.fighter_b.state_machine.state != FighterStateMachine.State.CHARGE, "Strike interrupts Doge charge with no armor")

    var projectile := _battle(generic, doge)
    _start_move(projectile.fighter_b, &"doge_rush_l3", 7)
    var projectile_contact := ProjectileContact.new()
    projectile_contact.attacker_id = 1; projectile_contact.defender_id = 2; projectile_contact.move_id = MoveIds.SPECIAL_NEUTRAL
    projectile_contact.attack_instance_id = 99; projectile_contact.projectile_instance_id = 1; projectile_contact.projectile_id = &"zone_shot"; projectile_contact.incoming_direction_x = -1
    var projectile_data := load("res://data/projectiles/zone_shot.tres") as ProjectileData
    var projectile_result := projectile.combat_resolver.resolve_projectile_contact(projectile_contact, projectile_data, projectile.fighter_a, projectile.fighter_b)
    t.equal(projectile_result.result_type, HitResult.ResultType.HIT, "Strike-only Lv3 armor does not absorb projectile damage kind")
    projectile.combat_resolver.apply_strike_result(1, projectile_result, projectile.fighter_a, projectile.fighter_b, [])
    t.that(not projectile.fighter_b.move_runner.is_running(), "Projectile interrupts Lv3 Rush rather than granting invulnerability")

    var risk := doge.move_set.moves.filter(func(move: MoveData): return move.id == &"doge_rush_l3")[0] as MoveData
    t.equal(risk.recovery_frames, 22, "Doge Lv3 preserves 22F whiff/block recovery")
    var blocked := _battle(doge, generic)
    _start_move(blocked.fighter_a, &"doge_rush_l3", risk.first_active_frame())
    _tick(blocked, null, _guard(1))
    t.equal(blocked.fighter_b.combatant.last_result_type, HitResult.ResultType.BLOCK, "Doge Lv3 remains normally blockable")
    t.that(blocked.fighter_a.move_runner.is_running(), "Blocked Lv3 retains authored committed recovery")
    var whiff := _battle(doge, generic, 50000, 110000)
    _start_move(whiff.fighter_a, &"doge_rush_l3", risk.last_active_frame() + 1)
    _tick(whiff)
    t.that(whiff.fighter_a.move_runner.is_running() and whiff.fighter_a.move_runner.phase() == &"RECOVERY", "Whiffed Lv3 remains committed in recovery")
    t.that(not whiff.fighter_a.mechanics_runtime.armor_active(whiff.fighter_a.move_runner, HitResult.AttackSourceKind.FIGHTER_BODY), "Lv3 armor is inactive during recovery")

func _test_doge_armor_snapshot() -> void:
    var battle := _battle(generic, doge)
    _start_move(battle.fighter_b, &"doge_rush_l3", 7)
    var snapshot := battle.capture_state()
    var signature := battle.state_signature()
    battle.fighter_b.mechanics_runtime.consume_armor()
    t.equal(battle.fighter_b.mechanics_runtime.armor_remaining_hits, 0, "Doge armor mutation consumes runtime hit")
    t.that(battle.restore_state(snapshot), "Doge Lv3 armor snapshot restores")
    t.equal(battle.fighter_b.mechanics_runtime.armor_remaining_hits, 1, "Snapshot restores one remaining Lv3 armor hit")
    t.equal(battle.state_signature(), signature, "Lv3 armor snapshot restores exact authoritative hash")
