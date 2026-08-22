# Responsibility: Produce gameplay rectangles and guard against duplicate resolved contacts.
# Owns: pushbox/hurtbox configuration and per-AttackInstance+HitID+Defender resolved-contact registry.
# Does NOT own: damage application, sprites, engine physics callbacks.
# Dependencies: CharacterData, BoxData, MoveRunner, and MoveHitData.
class_name HitboxOwner
extends RefCounted

var _pushbox: BoxData
var _hurtbox: BoxData
var _tracked_attack_instance_id: int = -1
var _contact_keys: Array[int] = []

func configure(data: CharacterData) -> void:
    _pushbox = data.pushbox
    _hurtbox = data.hurtbox
    reset_runtime()

func pushbox_rect(origin_pixels: Vector2, facing: int) -> Rect2:
    return _pushbox.world_rect(origin_pixels, facing)

func hurtbox_rect(origin_pixels: Vector2, facing: int, runner: MoveRunner = null) -> Rect2:
    if runner != null and runner.current_move != null:
        var override := runner.current_move.hurtbox_override_for_frame(runner.move_frame)
        if override != null and override.hurtbox != null:
            return override.hurtbox.world_rect(origin_pixels, facing)
    return _hurtbox.world_rect(origin_pixels, facing)

func active_hit_ids(runner: MoveRunner) -> Array[int]:
    if runner == null or runner.current_move == null:
        return []
    return runner.current_move.active_hit_ids_for_frame(runner.move_frame)

func active_hitbox_rect_for_hit(origin_pixels: Vector2, facing: int, runner: MoveRunner, hit_id: int) -> Rect2:
    if runner == null or runner.current_move == null:
        return Rect2()
    var payload = runner.current_move.payload_for_hit_id(hit_id)
    if payload == null:
        return Rect2()
    var box: BoxData = payload.hitbox if payload is MoveHitData else runner.current_move.hitbox
    if box == null:
        return Rect2()
    return box.world_rect(origin_pixels, facing)

# Compatibility: returns the first active hitbox in canonical hit-id order.
func active_hitbox_rect(origin_pixels: Vector2, facing: int, runner: MoveRunner) -> Rect2:
    var ids := active_hit_ids(runner)
    if ids.is_empty():
        return Rect2()
    return active_hitbox_rect_for_hit(origin_pixels, facing, runner, ids[0])

func active_throw_rect(origin_pixels: Vector2, facing: int, runner: MoveRunner) -> Rect2:
    if runner.current_move == null or not runner.is_active_frame() or runner.current_move.throw_box == null:
        return Rect2()
    return runner.current_move.throw_box.world_rect(origin_pixels, facing)

func has_active_hitbox(runner: MoveRunner) -> bool:
    return not active_hit_ids(runner).is_empty()

func has_active_throw_box(runner: MoveRunner) -> bool:
    return runner.current_move != null and runner.is_active_frame() and runner.current_move.throw_box != null

func begin_attack_instance(attack_instance_id: int) -> void:
    if attack_instance_id != _tracked_attack_instance_id:
        _tracked_attack_instance_id = attack_instance_id
        _contact_keys.clear()

func can_hit_defender(attack_instance_id: int, defender_id: int, hit_id: int = 0) -> bool:
    _ensure_instance(attack_instance_id)
    return not _contact_keys.has(_key(hit_id, defender_id))

func record_hit(attack_instance_id: int, defender_id: int, hit_id: int = 0) -> void:
    _ensure_instance(attack_instance_id)
    var key := _key(hit_id, defender_id)
    if not _contact_keys.has(key):
        _contact_keys.append(key)
        _contact_keys.sort()

func tracked_attack_instance_id() -> int:
    return _tracked_attack_instance_id

# Legacy helper exposes only hit-id 0 defender IDs.
func contacted_defender_ids() -> Array[int]:
    var out: Array[int] = []
    for key in _contact_keys:
        var hit_id := key / 10000
        var defender_id := key % 10000
        if hit_id == 0 and not out.has(defender_id): out.append(defender_id)
    return out

func contacted_hit_keys() -> Array[int]:
    return _contact_keys.duplicate()

func restore_contact_registry(attack_instance_id: int, defender_ids: Array[int], hit_keys: Array[int] = []) -> void:
    _tracked_attack_instance_id = attack_instance_id
    _contact_keys.clear()
    if not hit_keys.is_empty():
        _contact_keys = hit_keys.duplicate(); _contact_keys.sort(); return
    for defender_id in defender_ids:
        _contact_keys.append(_key(0, defender_id))

func reset_runtime() -> void:
    _tracked_attack_instance_id = -1
    _contact_keys.clear()

func _ensure_instance(attack_instance_id: int) -> void:
    if attack_instance_id != _tracked_attack_instance_id:
        _tracked_attack_instance_id = attack_instance_id
        _contact_keys.clear()

func _key(hit_id: int, defender_id: int) -> int:
    return maxi(0, hit_id) * 10000 + maxi(0, defender_id)
