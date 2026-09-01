# Training/debug-only controls over the same authoritative BattleSimulation.
# Never installed for ordinary versus/CPU matches and never enters Replay/Snapshot truth.
class_name TrainingController
extends RefCounted

var enabled: bool = false
var infinite_hp: bool = true
var infinite_meter: bool = true
var simulation: BattleSimulation = null

func configure(p_simulation: BattleSimulation, p_enabled: bool) -> void:
    simulation = p_simulation
    enabled = p_enabled
    _apply_infinite_flags()

func set_infinite_hp(value: bool) -> void:
    infinite_hp = value
    _apply_infinite_flags()

func set_infinite_meter(value: bool) -> void:
    infinite_meter = value
    _apply_infinite_flags()
    if enabled and value and simulation != null:
        simulation.fighter_a.meter.set_value(MeterComponent.MAX_VALUE)
        simulation.fighter_b.meter.set_value(MeterComponent.MAX_VALUE)

func reset_positions() -> void:
    if enabled and simulation != null:
        simulation.reset_training_state()
        _apply_infinite_flags()
        if infinite_meter:
            simulation.fighter_a.meter.set_value(MeterComponent.MAX_VALUE)
            simulation.fighter_b.meter.set_value(MeterComponent.MAX_VALUE)

func set_meter(fighter_id: int, value: int) -> bool:
    var fighter := _fighter(fighter_id)
    if not enabled or fighter == null: return false
    fighter.meter.set_value(value); return true

func set_resource(fighter_id: int, resource_id: StringName, value: int) -> bool:
    var fighter := _fighter(fighter_id)
    return enabled and fighter != null and fighter.resources.set_value(resource_id, value)

func toggle_status(fighter_id: int, status_id: StringName) -> bool:
    var fighter := _fighter(fighter_id)
    if not enabled or fighter == null: return false
    if fighter.has_status(status_id): return fighter.statuses.remove_status(status_id)
    return fighter.statuses.apply_defined(status_id)

func activate_mode(fighter_id: int, mode_id: StringName) -> bool:
    var fighter := _fighter(fighter_id)
    if not enabled or fighter == null: return false
    if fighter.get_active_mode_id() == mode_id: fighter.mode.exit(); return true
    return fighter.mode.enter(mode_id, -1, simulation.frame_number)

func trigger_move_start_effects(fighter_id: int, move_id: StringName) -> bool:
    var fighter := _fighter(fighter_id)
    if not enabled or fighter == null or simulation == null: return false
    var move := fighter.move_registry.get_move(move_id)
    if move == null: return false
    var opponent := simulation.fighter_b if fighter == simulation.fighter_a else simulation.fighter_a
    simulation.combat_resolver.effect_executor.execute_all(move.on_start_effects, fighter, opponent, simulation.temporary_entity_system, GameplayConditionEvaluator.contact_flags(opponent), BattleSimulation.STAGE_LEFT_UNITS, BattleSimulation.STAGE_RIGHT_UNITS)
    return true

func _apply_infinite_flags() -> void:
    if simulation == null: return
    for fighter: Fighter in [simulation.fighter_a, simulation.fighter_b]:
        if fighter == null: continue
        fighter.combatant.training_infinite_hp = enabled and infinite_hp
        fighter.meter.training_infinite_meter = enabled and infinite_meter
        if enabled and infinite_meter: fighter.meter.set_value(MeterComponent.MAX_VALUE)

func _fighter(fighter_id: int) -> Fighter:
    return simulation.fighter_by_id(fighter_id) if simulation != null else null
