# Presentation-only Ultimate background/cut-in/overlay presenter.
# Gameplay Ultimate timing/freeze/damage remain authoritative elsewhere.
class_name UltimateScreenPresenter
extends CanvasLayer

const PULSE_SCRIPT := preload("res://presentation/ultimates/ultimate_screen_pulse.gd")

var simulation: BattleSimulation
var _presentations: Dictionary = {}
var _active_nodes: Array[Node] = []

func configure(p_simulation: BattleSimulation, presentations: Array[CharacterPresentationData]) -> void:
    clear_all()
    simulation = p_simulation
    _presentations.clear()
    for data: CharacterPresentationData in presentations:
        if data != null:
            data.rebuild_cache()
            _presentations[data.character_id] = data

func present_event(event: CombatEvent) -> void:
    if event == null:
        return
    if event.type in [CombatEvent.EventType.ROUND_STARTED, CombatEvent.EventType.ROUND_ENDED, CombatEvent.EventType.MATCH_ENDED]:
        clear_all()
        return
    if event.type != CombatEvent.EventType.MOVE_STARTED:
        return
    if event.move_id != &"ultimate" and not _is_finisher_move(event.move_id):
        return
    if simulation == null:
        return
    var fighter := simulation.fighter_by_id(event.attacker_id)
    if fighter == null or fighter.data == null:
        return
    var data: CharacterPresentationData = _presentations.get(fighter.data.id, null) as CharacterPresentationData
    if data == null:
        return
    var binding := data.ultimate_binding(event.move_id)
    var production: ProductionAnimationBinding = null
    if data.production_asset_binding != null:
        production = data.production_asset_binding.first_binding_for_move(event.move_id, ProductionAnimationBinding.Domain.ULTIMATE_SCREEN)
    clear_all()
    _spawn_pulse(data, CombatFeedbackProfile.tier_for_move(event.move_id) >= 4)
    if binding != null:
        _instantiate(binding.background_scene, 0)
        _instantiate(binding.overlay_scene, 20)
        _instantiate(binding.cutin_scene, 30)
    if production != null:
        var node := load("res://presentation/visuals/production/inventory_bound_effect_visual.tscn").instantiate() as Node2D
        if node != null:
            add_child(node)
            node.position = Vector2(640, 360)
            node.call("configure_binding", production, 1, 1.0)
            node.z_index = 5
            _active_nodes.append(node)

func _is_finisher_move(move_id: StringName) -> bool:
    return "finisher" in String(move_id)

func _spawn_pulse(data: CharacterPresentationData, finisher: bool) -> void:
    var pulse := PULSE_SCRIPT.new() as ColorRect
    if pulse == null:
        return
    add_child(pulse)
    pulse.configure(data.placeholder_color, 0.42 if finisher else 0.30, 0.30 if finisher else 0.20)
    pulse.z_index = 1
    _active_nodes.append(pulse)

func _instantiate(scene: PackedScene, order: int) -> void:
    if scene == null:
        return
    var node := scene.instantiate()
    add_child(node)
    if node is CanvasItem:
        (node as CanvasItem).z_index = order
    _active_nodes.append(node)

func clear_all() -> void:
    for node: Node in _active_nodes:
        if node != null and is_instance_valid(node):
            node.queue_free()
    _active_nodes.clear()

func active_count() -> int:
    return _active_nodes.size()
