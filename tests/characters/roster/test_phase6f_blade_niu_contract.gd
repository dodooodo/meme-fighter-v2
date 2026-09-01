# Phase 6F real-runtime mode/block and Courage cashout contracts.
class_name Phase6FBladeNiuContractTests
extends RefCounted

const ASSERT_HELPER := preload("res://tests/test_assert.gd")

var t = ASSERT_HELPER.new()
var blade: CharacterData
var niu: CharacterData
var generic: CharacterData

func run_all() -> int:
    blade = RosterRegistry.character_by_id(&"blade_shield")
    niu = RosterRegistry.character_by_id(&"niu_lai")
    generic = load("res://data/characters/generic_fighter.tres") as CharacterData
    _test_blade_block_and_mode_contract()
    _test_niu_courage_contract()
    print("\nPhase 6F Blade/Niu contract tests: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed

func _battle(a: CharacterData, b: CharacterData, ax: int = 50000, bx: int = 60000) -> BattleSimulation:
    var battle := BattleSimulation.new()
    battle.configure(a, b, null, null, Vector2i(ax, BattleSimulation.GROUND_Y_UNITS), Vector2i(bx, BattleSimulation.GROUND_Y_UNITS))
    return battle

func _tick(battle: BattleSimulation, a: InputFrame = null, b: InputFrame = null) -> void:
    var frame := battle.frame_number + 1
    battle.simulate_frame(a if a != null else InputFrame.neutral(frame), b if b != null else InputFrame.neutral(frame))

func _guard(frame: int) -> InputFrame:
    return InputFrame.new(frame, 0, 0, InputFrame.InputButton.GUARD, InputFrame.InputButton.GUARD, 0)

func _start_active(fighter: Fighter, move_id: StringName) -> MoveData:
    var move := fighter.move_registry.get_move(move_id)
    fighter.move_runner.interrupt()
    if move != null:
        fighter.move_runner.start_move(move)
        fighter.hitbox_owner.begin_attack_instance(fighter.move_runner.attack_instance_id)
        fighter.state_machine.transition_to(FighterStateMachine.State.GROUND_ATTACK)
        fighter.move_runner.move_frame = move.first_active_frame()
    return move

func _event_count(battle: BattleSimulation, kind: int) -> int:
    var result := 0
    for event: CombatEvent in battle.drain_events():
        if event.type == kind:
            result += 1
    return result

func _blade_block_result(defender_data: CharacterData, defender_x: int = 60000) -> Dictionary:
    var battle := _battle(blade, defender_data, 50000, defender_x)
    var before := battle.fighter_b.movement_motor.sim_position.x
    _start_active(battle.fighter_a, &"blade_slash_l2")
    _tick(battle, null, _guard(battle.frame_number + 1))
    return {
        "events": _event_count(battle, CombatEvent.EventType.BLOCK),
        "blockstun": battle.fighter_b.combatant.blockstun_remaining,
        "push": absi(battle.fighter_b.movement_motor.sim_position.x - before),
        "position": battle.fighter_b.movement_motor.sim_position.x,
    }

func _test_blade_block_and_mode_contract() -> void:
    var baseline := _blade_block_result(generic)
    var shield := _blade_block_result(blade)
    t.equal(baseline.events, 1, "Generic baseline actually blocks Blade Special")
    t.equal(shield.events, 1, "Blade Shield actually blocks the same Special")
    t.equal(shield.blockstun, baseline.blockstun, "Shield Stability preserves authored blockstun")
    t.that(shield.push < baseline.push, "Shield Stability reduces only defender block pushback")

    var heavy := _battle(blade, blade).fighter_a.move_registry.get_move(MoveIds.STAND_HEAVY)
    for hit in heavy.hits:
        var multi := _battle(blade, blade)
        _start_active(multi.fighter_a, MoveIds.STAND_HEAVY)
        multi.fighter_a.move_runner.move_frame = hit.active_start_frame
        _tick(multi, null, _guard(multi.frame_number + 1))
        t.equal(multi.fighter_b.combatant.blockstun_remaining, hit.blockstun_frames, "Shield block retains blockstun on Heavy hit %d" % hit.hit_id)

    var corner := _blade_block_result(blade, BattleSimulation.STAGE_RIGHT_UNITS - 100)
    t.that(corner.position <= BattleSimulation.STAGE_RIGHT_UNITS, "Shield block pushback obeys the stage-right clamp")

    var dual := _battle(generic, blade)
    t.that(dual.fighter_b.mode.enter(&"dual_blade", 480, dual.frame_number), "Blade enters authored Dual-Blade mode")
    _start_active(dual.fighter_a, MoveIds.STAND_LIGHT)
    _tick(dual, null, _guard(dual.frame_number + 1))
    t.equal(_event_count(dual, CombatEvent.EventType.BLOCK), 0, "Dual-Blade cannot guard")
    t.equal(dual.fighter_b.combatant.last_result_type, HitResult.ResultType.HIT, "Dual-Blade guard input resolves as a hit")
    var return_mode := _battle(generic, blade)
    t.that(return_mode.fighter_b.mode.enter(&"dual_blade", 480, return_mode.frame_number), "Blade can enter Dual-Blade before return test")
    return_mode.fighter_b.mode.exit()
    _start_active(return_mode.fighter_a, MoveIds.STAND_LIGHT)
    _tick(return_mode, null, _guard(return_mode.frame_number + 1))
    t.equal(_event_count(return_mode, CombatEvent.EventType.BLOCK), 1, "Exiting Dual-Blade restores normal Guard")

    var snapshot_battle := _battle(blade, generic)
    snapshot_battle.fighter_a.mode.enter(&"dual_blade", 240, snapshot_battle.frame_number)
    var snapshot := snapshot_battle.capture_state()
    for _i in range(4): _tick(snapshot_battle)
    var hash := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "Blade Dual-Blade snapshot restores")
    for _i in range(4): _tick(snapshot_battle)
    t.equal(snapshot_battle.state_signature(), hash, "Blade mode timer and guard permission replay identically")

func _start_niu_ultimate(battle: BattleSimulation, courage: int) -> void:
    battle.fighter_a.meter.restore_value(100)
    battle.fighter_a.resources.set_value(&"courage", courage)
    _tick(battle, InputFrame.with_ultimate_press(battle.frame_number + 1))

func _test_niu_courage_contract() -> void:
    var start := _battle(niu, generic)
    t.equal(start.fighter_a.resources.get_value(&"courage"), 0, "Niu round starts at Courage 0")
    start.fighter_a.resources.gain(&"courage", 1)
    t.equal(start.fighter_a.resources.get_value(&"courage"), 1, "Authored generic Courage gain reaches 1")
    start.fighter_a.resources.gain(&"courage", 5)
    t.equal(start.fighter_a.resources.get_value(&"courage"), 3, "Courage gain clamps at 3")
    t.equal(start.fighter_a.resources.movement_permille(&"walk_forward"), 1095, "Courage 2+ retains authored mobility threshold")
    start.fighter_a.resources.set_value(&"courage", 1)
    t.equal(start.fighter_a.resources.movement_permille(&"walk_forward"), 1000, "Courage below Lv2 threshold has no mobility boost")
    var charge_entry := start.fighter_a.move_registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    t.equal(charge_entry.charge_special_data.level_3_move_id, &"niu_special_l3", "Courage retains authored Lv3 Special routing")

    var base_ultimate := _battle(niu, generic)
    _start_niu_ultimate(base_ultimate, 0)
    t.equal(base_ultimate.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "Niu retains its authored 0-Courage Ultimate")
    t.equal(base_ultimate.fighter_a.resources.get_value(&"courage"), 0, "0-Courage Ultimate has no invalid resource mutation")

    for value in [1, 2, 3]:
        var cashout := _battle(niu, generic)
        _start_niu_ultimate(cashout, value)
        t.equal(cashout.fighter_a.move_runner.current_move_id(), MoveIds.ULTIMATE, "Niu Ultimate starts at Courage %d" % value)
        t.equal(cashout.fighter_a.resources.get_value(&"courage"), 0, "Niu Ultimate cashes out all Courage at %d" % value)
        t.equal(cashout.fighter_a.move_runner.activation_resource_value(&"courage"), value, "Niu Ultimate preserves its activation tier %d" % value)
        var ultimate := cashout.fighter_a.move_runner.current_move
        var expected_damage: int = [0, 185, 220, 265][value]
        var payload: MoveHitData = null
        for hit in ultimate.hits:
            if GameplayConditionEvaluator.matches_all(hit.conditions, cashout.fighter_a, cashout.fighter_b):
                payload = hit
        t.equal(payload.damage if payload != null else -1, expected_damage, "Niu Ultimate keeps authored Courage %d damage tier" % value)

    for guard in [false, true]:
        var result := _battle(niu, generic)
        _start_niu_ultimate(result, 3)
        result.fighter_a.move_runner.move_frame = result.fighter_a.move_runner.current_move.first_active_frame()
        _tick(result, null, _guard(result.frame_number + 1) if guard else null)
        t.equal(result.fighter_a.resources.get_value(&"courage"), 0, "Ultimate %s has no Courage refund" % ("block" if guard else "hit/whiff"))
    var whiff := _battle(niu, generic, 50000, 90000)
    _start_niu_ultimate(whiff, 2)
    t.equal(whiff.fighter_a.resources.get_value(&"courage"), 0, "Ultimate whiff commits Courage at activation")

    var heavy_kd := _battle(niu, niu)
    heavy_kd.fighter_a.meter.restore_value(100)
    heavy_kd.fighter_a.resources.set_value(&"courage", 3)
    heavy_kd.fighter_b.resources.set_value(&"courage", 3)
    _tick(heavy_kd, InputFrame.with_ultimate_press(heavy_kd.frame_number + 1))
    heavy_kd.fighter_a.move_runner.move_frame = heavy_kd.fighter_a.move_runner.current_move.first_active_frame()
    _tick(heavy_kd)
    t.equal(heavy_kd.fighter_b.resources.get_value(&"courage"), 3, "Heavy Knockdown does not remove defender Courage")

    var normal_damage := _battle(generic, niu)
    normal_damage.fighter_b.resources.set_value(&"courage", 2)
    _start_active(normal_damage.fighter_a, MoveIds.STAND_LIGHT)
    _tick(normal_damage)
    t.equal(normal_damage.fighter_b.resources.get_value(&"courage"), 2, "Ordinary damage has no hidden Courage tax")
    normal_damage.fighter_b.combatant.hp = 100
    for _i in range(30): _tick(normal_damage)
    t.equal(normal_damage.fighter_b.resources.get_value(&"courage"), 2, "Low HP has no Courage rubber-band gain")
    normal_damage.fighter_b.resources.set_value(&"courage", 3)
    normal_damage.fighter_b.reset_for_round(normal_damage.configured_start_position(2), normal_damage.fighter_b.movement_motor.facing, true, false)
    t.equal(normal_damage.fighter_b.resources.get_value(&"courage"), 0, "Niu round reset returns Courage to 0")

    var snapshot_battle := _battle(niu, generic)
    _start_niu_ultimate(snapshot_battle, 2)
    var snapshot := snapshot_battle.capture_state()
    snapshot_battle.fighter_a.move_runner.move_frame = snapshot_battle.fighter_a.move_runner.current_move.first_active_frame()
    _tick(snapshot_battle)
    var hash := snapshot_battle.state_signature()
    t.that(snapshot_battle.restore_state(snapshot), "Niu activation-tier snapshot restores")
    snapshot_battle.fighter_a.move_runner.move_frame = snapshot_battle.fighter_a.move_runner.current_move.first_active_frame()
    _tick(snapshot_battle)
    t.equal(snapshot_battle.state_signature(), hash, "Niu Ultimate cashout snapshot replays identical hash")
