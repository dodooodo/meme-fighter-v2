# Responsibility: Generic runtime progression, detached-spawn bookkeeping, and cancel connection facts for current MoveData.
# Owns: current move/frame, attack instance identity, per-fighter serial, spawned descriptor indices, HIT/BLOCK connection facts.
# Does NOT own: HP, input device, meter, state legality, collision resolution, projectile runtime entities, animation, HUD, individual move behavior.
# Dependencies: MoveData, CancelWindowData, MoveRegistry.
class_name MoveRunner
extends RefCounted

var current_move: MoveData
var move_frame: int = 0
var attack_instance_id: int = 0
var connected_hit: bool = false
var connected_block: bool = false
var _owner_id: int = 0
var _instance_serial: int = 0
var _spawned_projectile_indices: Array[int] = []
var _pending_completion_effects: Array[GameplayEffectData] = []
var _pending_completed_move_id: StringName = &""

func configure(owner_id: int) -> void:
    _owner_id = owner_id

func start_move(move: MoveData) -> bool:
    if move == null or current_move != null:
        return false
    _begin_move(move)
    return true

func start_cancel(move: MoveData) -> bool:
    if move == null or current_move == null:
        return false
    _begin_move(move)
    return true

func interrupt() -> void:
    current_move = null
    move_frame = 0
    connected_hit = false
    connected_block = false
    _spawned_projectile_indices.clear()

# Round reset clears active move/spawn bookkeeping while preserving the per-match attack serial by default.
func reset_runtime(reset_instance_serial: bool = false) -> void:
    interrupt()
    _pending_completion_effects.clear()
    _pending_completed_move_id = &""
    attack_instance_id = 0
    if reset_instance_serial:
        _instance_serial = 0

func is_running() -> bool:
    return current_move != null

func is_active_frame() -> bool:
    return current_move != null and current_move.is_active_frame(move_frame)

func phase() -> StringName:
    if current_move == null:
        return &"NONE"
    return current_move.phase_for_frame(move_frame)

func finalize_tick(frozen_by_hitstop: bool) -> void:
    if current_move == null or frozen_by_hitstop:
        return
    if move_frame >= current_move.total_frames():
        _pending_completed_move_id = current_move.id
        _pending_completion_effects = current_move.on_complete_effects.duplicate()
        interrupt()
        return
    move_frame += 1

func payload_for_hit_id(hit_id: int):
    return current_move.payload_for_hit_id(hit_id) if current_move != null else null

func consume_completion_effects() -> Array[GameplayEffectData]:
    var out: Array[GameplayEffectData] = _pending_completion_effects.duplicate()
    _pending_completion_effects.clear()
    _pending_completed_move_id = &""
    return out

func pending_completed_move_id() -> StringName:
    return _pending_completed_move_id

func current_move_id() -> StringName:
    return current_move.id if current_move != null else &""

func instance_serial() -> int:
    return _instance_serial

func owner_id() -> int:
    return _owner_id

func spawned_projectile_indices() -> Array[int]:
    return _spawned_projectile_indices.duplicate()

# Called by BattleSimulation once per non-hitstop simulation tick after old projectiles advance.
# Descriptor indices are persisted so the same MoveRunner frame cannot spawn twice during hitstop or restore/re-sim.
func consume_projectile_spawn_indices() -> Array[int]:
    var pending: Array[int] = []
    if current_move == null or move_frame <= 0:
        return pending
    for i in range(current_move.projectile_spawns.size()):
        var descriptor: ProjectileSpawnData = current_move.projectile_spawns[i]
        if descriptor == null or descriptor.spawn_frame != move_frame or _spawned_projectile_indices.has(i):
            continue
        _spawned_projectile_indices.append(i)
        pending.append(i)
    return pending

func mark_connected_hit(instance_id: int) -> void:
    if current_move != null and instance_id == attack_instance_id:
        connected_hit = true

func mark_connected_block(instance_id: int) -> void:
    if current_move != null and instance_id == attack_instance_id:
        connected_block = true

func connection_name() -> String:
    if connected_hit and connected_block:
        return "HIT+BLOCK"
    if connected_hit:
        return "HIT"
    if connected_block:
        return "BLOCK"
    return "NONE"

func can_cancel_to(target_move_id: StringName, resources: FighterResourceComponent = null) -> bool:
    if current_move == null or target_move_id == &"":
        return false
    for window: CancelWindowData in current_move.cancel_windows:
        if window == null:
            continue
        if window.contains_frame(move_frame) and window.allows_target(target_move_id) and window.condition_met(connected_hit, connected_block) and window.resource_condition_met(resources):
            return true
    return false


func active_dash_cancel_window() -> CancelWindowData:
    if current_move == null:
        return null
    for window: CancelWindowData in current_move.cancel_windows:
        if window != null and window.contains_frame(move_frame) and window.condition_met(connected_hit, connected_block) and window.allows_dash_forward():
            return window
    return null

func can_cancel_to_dash() -> bool:
    return active_dash_cancel_window() != null

func cancel_window_active() -> bool:
    if current_move == null:
        return false
    for window: CancelWindowData in current_move.cancel_windows:
        if window != null and window.contains_frame(move_frame) and window.condition_met(connected_hit, connected_block):
            return true
    return false

func active_cancel_targets() -> Array[StringName]:
    var targets: Array[StringName] = []
    if current_move == null:
        return targets
    for window: CancelWindowData in current_move.cancel_windows:
        if window == null or not window.contains_frame(move_frame) or not window.condition_met(connected_hit, connected_block):
            continue
        for target: StringName in window.allowed_target_move_ids:
            if not targets.has(target):
                targets.append(target)
    return targets

func restore_runtime(
    registry: MoveRegistry,
    move_id: StringName,
    p_move_frame: int,
    p_attack_instance_id: int,
    p_instance_serial: int,
    p_connected_hit: bool = false,
    p_connected_block: bool = false,
    p_spawned_projectile_indices: Array[int] = []
) -> bool:
    current_move = null
    move_frame = 0
    attack_instance_id = p_attack_instance_id
    _instance_serial = maxi(0, p_instance_serial)
    connected_hit = false
    connected_block = false
    _spawned_projectile_indices.clear()
    if move_id == &"":
        return p_spawned_projectile_indices.is_empty()
    var move := registry.get_move(move_id)
    if move == null:
        return false
    for index in p_spawned_projectile_indices:
        if index < 0 or index >= move.projectile_spawns.size() or _spawned_projectile_indices.has(index):
            return false
    current_move = move
    move_frame = clampi(p_move_frame, 1, maxi(1, move.total_frames()))
    connected_hit = p_connected_hit
    connected_block = p_connected_block
    _spawned_projectile_indices = p_spawned_projectile_indices.duplicate()
    return true

func _begin_move(move: MoveData) -> void:
    _instance_serial += 1
    attack_instance_id = _owner_id * 1000000 + _instance_serial
    current_move = move
    move_frame = 1
    connected_hit = false
    connected_block = false
    _spawned_projectile_indices.clear()
