# Read-only mirror of active ProjectileRuntime entities into presentation Nodes.
class_name ProjectileVisualPresenter
extends Node2D

var simulation: BattleSimulation
var _presentation_by_character: Dictionary = {}
var _visuals: Dictionary = {}

func configure(p_simulation: BattleSimulation, character_presentations: Array[CharacterPresentationData]) -> void:
    clear_all()
    simulation = p_simulation
    _presentation_by_character.clear()
    for data: CharacterPresentationData in character_presentations:
        if data != null:
            data.rebuild_cache()
            _presentation_by_character[data.character_id] = data
    sync_from_simulation()

func sync_from_simulation() -> void:
    if simulation == null:
        clear_all()
        return
    var live_ids: Dictionary = {}
    for projectile: ProjectileRuntime in simulation.projectile_system.active_projectiles():
        live_ids[projectile.instance_id] = true
        var visual: Node2D = _visuals.get(projectile.instance_id, null) as Node2D
        if visual == null or not is_instance_valid(visual):
            visual = _create_visual(projectile)
            _visuals[projectile.instance_id] = visual
        visual.position = SimulationRenderConverter.to_pixels(projectile.position_units)
        if visual.has_method("set_facing"):
            visual.call("set_facing", projectile.facing)
    var stale: Array = []
    for instance_id in _visuals.keys():
        if not live_ids.has(instance_id):
            stale.append(instance_id)
    for instance_id in stale:
        var node: Node = _visuals[instance_id]
        if node != null and is_instance_valid(node):
            node.queue_free()
        _visuals.erase(instance_id)

func clear_all() -> void:
    for node in _visuals.values():
        if node != null and is_instance_valid(node):
            node.queue_free()
    _visuals.clear()

func visual_count() -> int:
    return _visuals.size()

func has_visual(instance_id: int) -> bool:
    return _visuals.has(instance_id)

func visual_for(instance_id: int) -> Node2D:
    return _visuals.get(instance_id, null) as Node2D

func _create_visual(projectile: ProjectileRuntime) -> Node2D:
    var owner := simulation.fighter_by_id(projectile.owner_fighter_id)
    var character_id := owner.data.id if owner != null and owner.data != null else &""
    var presentation: CharacterPresentationData = _presentation_by_character.get(character_id, null) as CharacterPresentationData
    var binding := presentation.projectile_binding(projectile.projectile_id) if presentation != null else null
    var node: Node = binding.visual_scene.instantiate() if binding != null and binding.visual_scene != null else GreyboxProjectileVisual.new()
    var visual := node as Node2D
    add_child(visual)
    if visual.has_method("configure"):
        var color := binding.placeholder_color if binding != null else Color(0.9, 0.9, 0.9, 1.0)
        var scale_value := binding.visual_scale if binding != null else 1.0
        visual.call("configure", projectile.projectile_id, color, scale_value)
    return visual
