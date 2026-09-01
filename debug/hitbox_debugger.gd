# Responsibility: Read-only visualization of gameplay boxes.
# Owns: debug draw toggle and rendering.
# Does NOT own: box geometry truth, collision, damage, simulation mutation.
# Dependencies: BattleSimulation read-only queries.
class_name HitboxDebugger
extends Node2D

var simulation: BattleSimulation
var enabled: bool = true

func set_simulation(value: BattleSimulation) -> void:
    simulation = value
    queue_redraw()

func toggle() -> void:
    enabled = not enabled
    queue_redraw()

func _process(_delta: float) -> void:
    if enabled:
        queue_redraw()

func _draw() -> void:
    if not enabled or simulation == null:
        return
    _draw_boxes(simulation.fighter_a)
    _draw_boxes(simulation.fighter_b)
    for projectile: ProjectileRuntime in simulation.projectile_system.active_projectiles():
        _draw_projectile_box(projectile)
    for runtime: TemporaryEntityRuntime in simulation.temporary_entity_system.active_entities():
        _draw_temporary_entity_box(runtime)

func _draw_boxes(fighter: Fighter) -> void:
    var pos := fighter.position_pixels()
    var facing := fighter.movement_motor.facing
    var pushbox := fighter.hitbox_owner.pushbox_rect(pos, facing)
    var hurtbox := fighter.hitbox_owner.hurtbox_rect(pos, facing)
    draw_rect(pushbox, Color(0.20, 0.55, 1.0, 0.20), true)
    draw_rect(pushbox, Color(0.20, 0.55, 1.0, 0.95), false, 2.0)
    draw_rect(hurtbox, Color(0.20, 1.0, 0.35, 0.12), true)
    draw_rect(hurtbox, Color(0.20, 1.0, 0.35, 0.90), false, 2.0)
    if fighter.hitbox_owner.has_active_hitbox(fighter.move_runner):
        var hitbox := fighter.hitbox_owner.active_hitbox_rect(pos, facing, fighter.move_runner)
        draw_rect(hitbox, Color(1.0, 0.15, 0.15, 0.28), true)
        draw_rect(hitbox, Color(1.0, 0.15, 0.15, 1.0), false, 2.5)
    if fighter.hitbox_owner.has_active_throw_box(fighter.move_runner):
        var throw_range := fighter.hitbox_owner.active_throw_rect(pos, facing, fighter.move_runner)
        draw_rect(throw_range, Color(1.0, 0.75, 0.15, 0.22), true)
        draw_rect(throw_range, Color(1.0, 0.75, 0.15, 1.0), false, 2.5)

func _draw_projectile_box(projectile: ProjectileRuntime) -> void:
    if projectile == null or projectile.projectile_data == null:
        return
    var rect := projectile.gameplay_rect()
    draw_rect(rect, Color(1.0, 0.35, 0.85, 0.24), true)
    draw_rect(rect, Color(1.0, 0.35, 0.85, 1.0), false, 2.5)


func _draw_temporary_entity_box(runtime: TemporaryEntityRuntime) -> void:
    if runtime == null or simulation == null:
        return
    var data := simulation.temporary_entity_system.data_for_id(runtime.data_id)
    var center := SimulationRenderConverter.to_pixels(runtime.position_units)
    if data is AreaData:
        var half := SimulationRenderConverter.to_pixels((data as AreaData).half_extents_units)
        _draw_world_rect(Rect2(center - Vector2(absf(half.x), absf(half.y)), Vector2(absf(half.x), absf(half.y)) * 2.0), Color(0.85, 0.3, 1.0, 1.0))
    elif data is HazardData:
        var half := SimulationRenderConverter.to_pixels((data as HazardData).half_extents_units)
        _draw_world_rect(Rect2(center - Vector2(absf(half.x), absf(half.y)), Vector2(absf(half.x), absf(half.y)) * 2.0), Color(1.0, 0.35, 0.1, 1.0))
    elif data is SummonData:
        var summon := data as SummonData
        var hurt_half := SimulationRenderConverter.to_pixels(summon.hurtbox_half_extents_units)
        _draw_world_rect(Rect2(center - Vector2(absf(hurt_half.x), absf(hurt_half.y)), Vector2(absf(hurt_half.x), absf(hurt_half.y)) * 2.0), Color(0.3, 0.95, 0.95, 1.0))
        if runtime.phase == 2:
            var hit_half := SimulationRenderConverter.to_pixels(summon.hitbox_half_extents_units)
            _draw_world_rect(Rect2(center - Vector2(absf(hit_half.x), absf(hit_half.y)), Vector2(absf(hit_half.x), absf(hit_half.y)) * 2.0), Color(1.0, 0.2, 0.65, 1.0))

func _draw_world_rect(rect: Rect2, outline: Color) -> void:
    var fill := Color(outline.r, outline.g, outline.b, 0.14)
    draw_rect(rect, fill, true)
    draw_rect(rect, outline, false, 2.0)
