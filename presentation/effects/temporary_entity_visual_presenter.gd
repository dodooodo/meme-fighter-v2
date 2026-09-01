# Read-only presentation mirror for TemporaryEntitySystem AREA/SUMMON/HAZARD/SEQUENCE runtimes.
# Runtime entity identity/position/lifetime are authoritative; this node only chooses inventory-backed art.
class_name TemporaryEntityVisualPresenter
extends Node2D

var simulation: BattleSimulation = null
var _presentation_by_character: Dictionary = {}
var _visuals: Dictionary = {}
const EFFECT_SCENE := preload("res://presentation/visuals/production/inventory_bound_effect_visual.tscn")

func configure(p_simulation: BattleSimulation, presentations: Array[CharacterPresentationData]) -> void:
    clear_all()
    simulation = p_simulation
    _presentation_by_character.clear()
    for data: CharacterPresentationData in presentations:
        if data != null:
            data.rebuild_cache()
            _presentation_by_character[data.character_id] = data
    sync_from_simulation()

func sync_from_simulation() -> void:
    if simulation == null:
        clear_all()
        return
    var live: Dictionary = {}
    for runtime: TemporaryEntityRuntime in simulation.temporary_entity_system.active_entities():
        live[runtime.instance_id] = true
        var visual: Node2D = _visuals.get(runtime.instance_id, null) as Node2D
        if visual == null or not is_instance_valid(visual):
            visual = _create_visual(runtime)
            if visual != null:
                _visuals[runtime.instance_id] = visual
        if visual != null:
            visual.position = SimulationRenderConverter.to_pixels(runtime.position_units)
            if visual.has_method("set_facing"):
                visual.call("set_facing", runtime.facing)
    var stale: Array = []
    for instance_id in _visuals.keys():
        if not live.has(instance_id): stale.append(instance_id)
    for instance_id in stale:
        var node: Node = _visuals[instance_id]
        if node != null and is_instance_valid(node): node.queue_free()
        _visuals.erase(instance_id)

func _create_visual(runtime: TemporaryEntityRuntime) -> Node2D:
    var owner := simulation.fighter_by_id(runtime.owner_fighter_id)
    if owner == null or owner.data == null:
        return null
    var data: CharacterPresentationData = _presentation_by_character.get(owner.data.id, null) as CharacterPresentationData
    if data == null or data.production_asset_binding == null:
        return null
    var domain := _domain_for_kind(runtime.kind)
    var candidates := data.production_asset_binding.bindings_for_entity(runtime.data_id, domain)
    if candidates.is_empty():
        return null
    # Deterministic presentation selection from immutable runtime identity/phase; it cannot affect gameplay.
    var index := posmod(runtime.instance_id + runtime.phase, candidates.size())
    var binding: ProductionAnimationBinding = candidates[index]
    var visual := EFFECT_SCENE.instantiate() as Node2D
    add_child(visual)
    visual.call("configure_binding", binding, runtime.facing, 1.0)
    return visual

func _domain_for_kind(kind: int) -> int:
    match kind:
        TemporaryEntityRuntime.Kind.AREA: return ProductionAnimationBinding.Domain.HAZARD
        TemporaryEntityRuntime.Kind.SUMMON: return ProductionAnimationBinding.Domain.SUMMON
        TemporaryEntityRuntime.Kind.HAZARD: return ProductionAnimationBinding.Domain.HAZARD
        TemporaryEntityRuntime.Kind.SEQUENCE: return ProductionAnimationBinding.Domain.HAZARD
    return ProductionAnimationBinding.Domain.WORLD_EFFECT

func clear_all() -> void:
    for node in _visuals.values():
        if node != null and is_instance_valid(node): node.queue_free()
    _visuals.clear()
