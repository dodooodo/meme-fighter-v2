# Presentation-only one-shot WORLD_EFFECT/HAZARD spawner.
# Uses deduped CombatEvent facts supplied by BattlePresentationController; never mutates gameplay.
class_name WorldEffectPresenter
extends Node2D

var _presentations: Dictionary = {}
var _fighter_controllers: Dictionary = {}
var spawn_count: int = 0

func configure(character_presentations: Array[CharacterPresentationData], fighter_controllers: Dictionary = {}) -> void:
    clear_all()
    _presentations.clear()
    _fighter_controllers = fighter_controllers.duplicate()
    for data: CharacterPresentationData in character_presentations:
        if data != null:
            data.rebuild_cache()
            _presentations[data.character_id] = data

func present_event(event: CombatEvent, simulation: BattleSimulation) -> void:
    if event == null or simulation == null:
        return
    var trigger := _trigger_for_event(event)
    if trigger < 0:
        return
    var fighter_id := event.attacker_id if event.attacker_id != 0 else event.defender_id
    var fighter := simulation.fighter_by_id(fighter_id)
    if fighter == null or fighter.data == null:
        return
    var data: CharacterPresentationData = _presentations.get(fighter.data.id, null) as CharacterPresentationData
    if data == null:
        return
    for binding: EffectPresentationBinding in data.effects_for_move(event.move_id, trigger):
        _spawn_binding(binding, fighter_id, event.position)
    _spawn_production_bindings(data, event, fighter, trigger)


func _spawn_production_bindings(data: CharacterPresentationData, event: CombatEvent, fighter: Fighter, trigger: int) -> void:
    if data == null or data.production_asset_binding == null:
        return
    var trigger_name := &"MOVE_STARTED"
    if trigger == EffectPresentationBinding.TriggerEvent.HIT: trigger_name = &"HIT"
    elif trigger == EffectPresentationBinding.TriggerEvent.BLOCK: trigger_name = &"BLOCK"
    for domain in [ProductionAnimationBinding.Domain.WORLD_EFFECT, ProductionAnimationBinding.Domain.HAZARD, ProductionAnimationBinding.Domain.ATTACHMENT]:
        for production: ProductionAnimationBinding in data.production_asset_binding.bindings_for_move(event.move_id, domain):
            if production.trigger_event != &"" and production.trigger_event != trigger_name:
                continue
            var visual := load("res://presentation/visuals/production/inventory_bound_effect_visual.tscn").instantiate() as Node2D
            if visual == null: continue
            add_child(visual)
            visual.global_position = event.position if event.position != Vector2.ZERO else fighter.position_pixels()
            visual.call("configure_binding", production, fighter.movement_motor.facing, 1.0)
            spawn_count += 1

func present_effect(character_id: StringName, effect_id: StringName, world_position: Vector2, facing: int = 1) -> Node2D:
    var data: CharacterPresentationData = _presentations.get(character_id, null) as CharacterPresentationData
    if data == null:
        return null
    var binding := data.effect_binding(effect_id)
    if binding == null:
        return null
    return _spawn_scene(binding, world_position, facing)

func _spawn_binding(binding: EffectPresentationBinding, fighter_id: int, event_position: Vector2) -> Node2D:
    var controller: FighterPresentationController = _fighter_controllers.get(fighter_id, null) as FighterPresentationController
    var position_value := event_position
    var facing := 1
    if controller != null and controller.visual != null:
        facing = controller.visual.current_facing
        if binding.anchor_socket != EffectPresentationBinding.AnchorSocket.CUSTOM_OFFSET:
            position_value = controller.visual.socket_world_position(binding.anchor_socket, binding.offset_pixels)
        else:
            position_value += binding.offset_pixels
    else:
        position_value += binding.offset_pixels
    return _spawn_scene(binding, position_value, facing)

func _spawn_scene(binding: EffectPresentationBinding, world_position: Vector2, facing: int) -> Node2D:
    var node: Node = binding.visual_scene.instantiate() if binding.visual_scene != null else load("res://presentation/visuals/production/production_world_effect_visual.tscn").instantiate()
    var visual := node as Node2D
    if visual == null:
        if node != null:
            node.queue_free()
        return null
    add_child(visual)
    visual.global_position = world_position
    visual.z_index = binding.z_index_offset
    if visual.has_method("configure"):
        visual.call("configure", binding.effect_id, Color.WHITE, binding.visual_scale)
    if binding.mirror_with_facing and visual.has_method("set_facing"):
        visual.call("set_facing", facing)
    spawn_count += 1
    return visual

func _trigger_for_event(event: CombatEvent) -> int:
    match event.type:
        CombatEvent.EventType.MOVE_STARTED:
            return EffectPresentationBinding.TriggerEvent.MOVE_STARTED
        CombatEvent.EventType.HIT:
            return EffectPresentationBinding.TriggerEvent.HIT
        CombatEvent.EventType.BLOCK:
            return EffectPresentationBinding.TriggerEvent.BLOCK
        _:
            return -1

func clear_all() -> void:
    for child in get_children():
        child.queue_free()
    spawn_count = 0
