# Responsibility: deterministic, reaction-limited, data-driven CPU policy -> canonical InputFrame only.
# Owns: delayed read-only observations, seeded utility selection, input edge composition.
# Does NOT own: Fighter mutation, HP/Meter, MoveRunner starts, state transitions, entities, collision, damage or physical input reads.
class_name CpuInputSource
extends InputSource

const DEFAULT_SEED: int = 0x28491
const DEFAULT_DIFFICULTY: StringName = &"normal"
const MAX_OBSERVATION_HISTORY: int = 180

var _own: Fighter = null
var _opponent: Fighter = null
var _simulation: BattleSimulation = null
var _profile: CpuUtilityProfile = null
var _difficulty: CpuDifficultyData = null
var _previous_held_bits: int = 0
var _seed: int = DEFAULT_SEED
var _decision_counter: int = 0
var _last_decision_frame: int = -9999
var _current_decision: StringName = &"idle"
var _charge_target_frames_planned: int = 0
var _observation_history: Dictionary = {}
var _last_reaction_frames: int = 0

func bind_context(own_fighter: Fighter, opponent_fighter: Fighter, simulation: BattleSimulation) -> bool:
    if own_fighter == null or opponent_fighter == null or simulation == null:
        return false
    _own = own_fighter
    _opponent = opponent_fighter
    _simulation = simulation
    _profile = CpuProfileRegistry.profile_for(StringName(_own.capture_combat_read()["character_id"]))
    if _difficulty == null:
        _difficulty = CpuProfileRegistry.difficulty_for(DEFAULT_DIFFICULTY)
    return _profile != null and _difficulty != null and _profile.is_valid() and _difficulty.is_valid()

func set_fixed_seed(value: int) -> void:
    _seed = value

func set_difficulty(id: StringName) -> bool:
    var loaded := CpuProfileRegistry.difficulty_for(id)
    if loaded == null or not loaded.is_valid():
        return false
    _difficulty = loaded
    return true

func set_profile(profile: CpuUtilityProfile) -> bool:
    if profile == null or not profile.is_valid():
        return false
    _profile = profile
    return true

func difficulty_id() -> StringName:
    return _difficulty.id if _difficulty != null else &""

func profile_character_id() -> StringName:
    return _profile.character_id if _profile != null else &""

func last_reaction_frames() -> int:
    return _last_reaction_frames

func sample(frame_number: int) -> InputFrame:
    if _own == null or _opponent == null or _simulation == null or _profile == null or _difficulty == null:
        return _compose_frame(frame_number, 0, 0, 0)
    _remember_observation(frame_number)

    var own_read := _own.capture_combat_read()
    var own_state := int(own_read["state_id"])
    if own_state == FighterStateMachine.State.CHARGE:
        return _sample_charge(frame_number)
    if bool(own_read["is_ko"]) or int(own_read["hitstun_remaining"]) > 0 or int(own_read["blockstun_remaining"]) > 0:
        return _compose_frame(frame_number, 0, 0, 0)
    if own_state in [FighterStateMachine.State.THROWN, FighterStateMachine.State.KNOCKDOWN, FighterStateMachine.State.GETUP, FighterStateMachine.State.LANDING]:
        return _compose_frame(frame_number, 0, 0, 0)

    _charge_target_frames_planned = 0
    if frame_number - _last_decision_frame >= _difficulty.decision_interval_frames:
        _decision_counter += 1
        _last_decision_frame = frame_number
        var span := maxi(1, _difficulty.reaction_max_frames - _difficulty.reaction_min_frames + 1)
        _last_reaction_frames = _difficulty.reaction_min_frames + (_roll(_decision_counter, 101) % span)
        var observed_frame := frame_number - _last_reaction_frames
        var observation: Dictionary = _observation_history.get(observed_frame, {})
        if observation.is_empty():
            _current_decision = &"idle"
        elif _roll(_decision_counter, 103) < _difficulty.decision_error_percent:
            _current_decision = _error_decision(observation)
        else:
            _current_decision = _choose_utility_decision(observation)
    var offset := maxi(0, frame_number - _last_decision_frame)
    return _frame_for_decision(frame_number, offset, _current_decision)

func reset() -> void:
    _previous_held_bits = 0
    _decision_counter = 0
    _last_decision_frame = -9999
    _current_decision = &"idle"
    _charge_target_frames_planned = 0
    _observation_history.clear()
    _last_reaction_frames = 0

func _remember_observation(frame_number: int) -> void:
    var own_read := _own.capture_combat_read()
    var opponent_read := _opponent.capture_combat_read()
    var own_position := own_read["position_units"] as Vector2i
    var opponent_position := opponent_read["position_units"] as Vector2i
    var distance := absi(opponent_position.x - own_position.x)
    _observation_history[frame_number] = {
        "distance": distance,
        "opponent_attacking": bool(opponent_read["current_move_running"]),
        "opponent_recovery": bool(opponent_read["current_move_running"]) and opponent_read["current_move_phase"] == &"RECOVERY",
        "opponent_low": int(opponent_read["current_move_hit_level"]) == MoveData.HitLevel.LOW,
        "opponent_airborne": bool(opponent_read["airborne"]),
        "opponent_grounded": bool(opponent_read["grounded"]),
        "own_airborne": bool(own_read["airborne"]),
        "own_grounded": bool(own_read["grounded"]),
        "opponent_guarding": bool(opponent_read["guarding"]),
        "opponent_cornered": _position_is_cornered(opponent_position.x),
        "own_cornered": _position_is_cornered(own_position.x),
        "own_hp": int(own_read["hp"]),
        "opponent_hp": int(opponent_read["hp"]),
        "own_meter": int(own_read["meter"]),
        "mode_active": own_read["active_mode_id"] != &"",
        "guard_allowed": bool(own_read["guard_allowed"]),
        "resource_total": int(own_read["resource_total"]),
        "projectiles": _simulation.projectile_system.active_projectiles().size(),
        "entities": _simulation.temporary_entity_system.active_entities().size(),
    }
    var oldest := frame_number - MAX_OBSERVATION_HISTORY
    _observation_history.erase(oldest)

func _choose_utility_decision(o: Dictionary) -> StringName:
    var candidates: Dictionary = {}
    var distance := int(o.get("distance", 0))
    var below_range := distance < _profile.preferred_range_min_units
    var above_range := distance > _profile.preferred_range_max_units
    var in_range := not below_range and not above_range

    if above_range:
        _add_weight(candidates, &"walk_forward", _profile.approach_weight * 2)
        _add_weight(candidates, &"dash", _profile.approach_weight)
        _add_weight(candidates, &"jump", _profile.jump_weight)
        _add_weight(candidates, &"special", _profile.special_lv2_weight + _profile.special_lv3_weight)
    elif below_range:
        _add_weight(candidates, &"walk_back", _profile.retreat_weight * 2)
        _add_weight(candidates, &"backstep", _profile.backstep_weight)
        _add_weight(candidates, &"light", _profile.light_weight)
        _add_weight(candidates, &"throw", _profile.throw_weight if bool(o.get("opponent_guarding", false)) else _profile.throw_weight / 2)
    else:
        _add_weight(candidates, &"heavy", _profile.heavy_weight)
        _add_weight(candidates, &"low", _profile.low_weight)
        _add_weight(candidates, &"light", _profile.light_weight)
        _add_weight(candidates, &"special", _profile.special_lv1_weight + _profile.special_lv2_weight)
        _add_weight(candidates, &"walk_forward", _profile.approach_weight / 2)
        _add_weight(candidates, &"walk_back", _profile.retreat_weight / 2)

    if bool(o.get("opponent_attacking", false)):
        if bool(o.get("guard_allowed", true)):
            _add_weight(candidates, &"guard_low" if bool(o.get("opponent_low", false)) else &"guard", _profile.guard_weight * 3)
        _add_weight(candidates, &"backstep", _profile.backstep_weight)
        _add_weight(candidates, &"special", _profile.counter_weight)
    if bool(o.get("opponent_airborne", false)):
        _add_weight(candidates, &"heavy", _profile.anti_air_weight * 2)
        _add_weight(candidates, &"guard", _profile.guard_weight)
    if bool(o.get("opponent_recovery", false)):
        _add_weight(candidates, &"heavy", _profile.heavy_weight * 2)
        _add_weight(candidates, &"special", _profile.special_lv2_weight)
    if bool(o.get("own_cornered", false)):
        _add_weight(candidates, &"jump", _profile.jump_weight * 2)
        _add_weight(candidates, &"backstep", _profile.backstep_weight / 2)
        _add_weight(candidates, &"walk_forward", _profile.approach_weight)
    if bool(o.get("opponent_cornered", false)):
        _add_weight(candidates, &"walk_forward", _profile.approach_weight)
        _add_weight(candidates, &"throw", _profile.throw_weight)
    if _can_use_ultimate():
        var ultimate_bonus := _profile.ultimate_weight
        if bool(o.get("opponent_recovery", false)) or bool(o.get("opponent_guarding", false)):
            ultimate_bonus += _profile.resource_spend_weight
        _add_weight(candidates, &"ultimate", ultimate_bonus)
    if bool(o.get("mode_active", false)):
        _add_weight(candidates, &"light", _profile.mode_activation_weight)
        _add_weight(candidates, &"heavy", _profile.mode_activation_weight)
    elif _can_use_ultimate():
        _add_weight(candidates, &"ultimate", _profile.mode_activation_weight / 2)
    if int(o.get("entities", 0)) == 0:
        _add_weight(candidates, &"ultimate", (_profile.summon_weight + _profile.trap_weight) / 2)
    if not bool(o.get("guard_allowed", true)):
        candidates.erase(&"guard")
        candidates.erase(&"guard_low")
    if not _has_special():
        candidates.erase(&"special")
    return _weighted_pick(candidates, _roll(_decision_counter, 107))

func _error_decision(o: Dictionary) -> StringName:
    var options: Array[StringName] = [&"idle", &"walk_forward", &"walk_back", &"crouch"]
    if bool(o.get("guard_allowed", true)): options.append(&"guard")
    return options[_roll(_decision_counter, 109) % options.size()]

func _weighted_pick(weights: Dictionary, roll: int) -> StringName:
    var keys: Array = weights.keys()
    keys.sort_custom(func(a, b): return String(a) < String(b))
    var total := 0
    for key in keys: total += maxi(0, int(weights[key]))
    if total <= 0: return &"idle"
    var point := posmod(roll * 9973 + _roll(_decision_counter, 113), total)
    var cursor := 0
    for key in keys:
        cursor += maxi(0, int(weights[key]))
        if point < cursor: return StringName(key)
    return &"idle"

func _add_weight(weights: Dictionary, action: StringName, amount: int) -> void:
    if amount <= 0: return
    weights[action] = int(weights.get(action, 0)) + amount

func _sample_charge(frame_number: int) -> InputFrame:
    if not _own.has_charge_special():
        return _compose_frame(frame_number, 0, 0, 0)
    if _charge_target_frames_planned <= 0:
        _charge_target_frames_planned = _charge_target_frames()
    var held := InputFrame.InputButton.SPECIAL if int(_own.capture_combat_read()["charge_frames"]) < _charge_target_frames_planned else 0
    return _compose_frame(frame_number, 0, 0, held)

func _charge_target_frames() -> int:
    var roll := _roll(_decision_counter, 127)
    var l1 := maxi(1, _profile.special_lv1_weight)
    var l2 := maxi(1, _profile.special_lv2_weight)
    var l3 := maxi(1, _profile.special_lv3_weight)
    var total := l1 + l2 + l3
    var point := roll * total / 100
    if point < l1: return 8 + (_roll(_decision_counter, 131) % 11)
    if point < l1 + l2: return 30 + (_roll(_decision_counter, 137) % 13)
    return 58 + (_roll(_decision_counter, 139) % 15)

func _frame_for_decision(frame_number: int, offset: int, decision: StringName) -> InputFrame:
    var direction_x := 0
    var direction_y := 0
    var held := 0
    var own_read := _own.capture_combat_read()
    var facing := -1 if int(own_read["facing"]) < 0 else 1
    match decision:
        &"walk_forward": direction_x = facing
        &"walk_back": direction_x = -facing
        &"guard": held = InputFrame.InputButton.GUARD if bool(own_read["guard_allowed"]) else 0
        &"guard_low":
            if bool(own_read["guard_allowed"]): direction_y = -1; held = InputFrame.InputButton.GUARD
        &"crouch": direction_y = -1
        &"light":
            if offset == 0: held = InputFrame.InputButton.LIGHT
        &"heavy":
            if offset == 0: held = InputFrame.InputButton.HEAVY
        &"low":
            if offset == 0: direction_y = -1; held = InputFrame.InputButton.LIGHT
        &"throw":
            if offset == 0: direction_x = facing; held = InputFrame.InputButton.HEAVY
        &"jump":
            if offset == 0: direction_y = 1
        &"special":
            if offset == 0: held = InputFrame.InputButton.SPECIAL
        &"ultimate":
            if offset == 0 and _can_use_ultimate(): held = InputFrame.InputButton.ULTIMATE
        &"dash":
            if offset == 0 or offset == 2: direction_x = facing
        &"backstep":
            if offset == 0 or offset == 2: direction_x = -facing
        _:
            pass
    return _compose_frame(frame_number, direction_x, direction_y, held)

func _compose_frame(frame_number: int, direction_x: int, direction_y: int, held: int) -> InputFrame:
    var pressed := held & ~_previous_held_bits
    var released := _previous_held_bits & ~held
    _previous_held_bits = held
    return InputFrame.new(frame_number, direction_x, direction_y, held, pressed, released)

func _has_special() -> bool:
    return _own != null and _own.has_move(MoveIds.SPECIAL_NEUTRAL)

func _can_use_ultimate() -> bool:
    return _own != null and _own.can_afford_move(MoveIds.ULTIMATE)

func _position_is_cornered(x: int) -> bool:
    return x <= BattleSimulation.STAGE_LEFT_UNITS + 3000 or x >= BattleSimulation.STAGE_RIGHT_UNITS - 3000

func _roll(counter: int, salt: int) -> int:
    # Stable integer mixing only: no wall clock, RandomNumberGenerator or physical input reads.
    var fighter_id := int(_own.capture_combat_read()["fighter_id"]) if _own != null else 0
    var value := int(counter) * 1103515245 + fighter_id * 12345 + _seed + salt * 265443576
    value = value ^ (value >> 16)
    value = value * 1664525 + 1013904223
    value = value ^ (value >> 13)
    return absi(value) % 100
