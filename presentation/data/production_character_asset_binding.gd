# Presentation-only inventory-backed production binding catalog for one gameplay character.
# It is intentionally excluded from Snapshot/Replay/Hasher and never mutates gameplay.
class_name ProductionCharacterAssetBinding
extends Resource

@export var character_id: StringName = &""
@export var display_name: String = ""
@export var asset_folder: String = ""
@export var source_inventory_path: String = "res://assets/production_roster/combat_asset_inventory.json"
@export var bindings: Array[ProductionAnimationBinding] = []
@export var approved_yellow_fallbacks: PackedStringArray = []

var _by_animation: Dictionary = {}
var _by_move: Dictionary = {}
var _modes: Dictionary = {}
var _by_entity: Dictionary = {}
var _cache_ready: bool = false

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if character_id == &"": errors.append("character_id must be non-empty")
    if display_name.strip_edges().is_empty(): errors.append("display_name must be non-empty")
    if asset_folder.strip_edges().is_empty(): errors.append("asset_folder must be non-empty")
    var exact_seen: Dictionary = {}
    for binding: ProductionAnimationBinding in bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid production animation binding")
            continue
        var exact_key := "%s|%s|%s" % [String(binding.mode_id), String(binding.animation_id), str(binding.domain)]
        if exact_seen.has(exact_key):
            errors.append("duplicate production binding: %s" % exact_key)
        exact_seen[exact_key] = true
        if binding.asset_folder != asset_folder:
            errors.append("asset_folder mismatch for %s" % String(binding.animation_id))
        for frame_path in binding.frame_paths:
            if not FileAccess.file_exists(frame_path):
                errors.append("missing production frame: %s" % frame_path)
    return errors

func rebuild_cache() -> bool:
    var errors := validate()
    if not errors.is_empty():
        return false
    _by_animation.clear(); _by_move.clear(); _by_entity.clear(); _modes.clear()
    for binding: ProductionAnimationBinding in bindings:
        var key := String(binding.animation_id)
        if not _by_animation.has(key): _by_animation[key] = []
        (_by_animation[key] as Array).append(binding)
        if binding.move_id != &"":
            var move_key := String(binding.move_id)
            if not _by_move.has(move_key): _by_move[move_key] = []
            (_by_move[move_key] as Array).append(binding)
        if binding.entity_id != &"":
            var entity_key := String(binding.entity_id)
            if not _by_entity.has(entity_key): _by_entity[entity_key] = []
            (_by_entity[entity_key] as Array).append(binding)
        if binding.mode_id != &"": _modes[String(binding.mode_id)] = true
    _cache_ready = true
    return true

func binding_for_animation(animation_id: StringName, mode_id: StringName = &"") -> ProductionAnimationBinding:
    _ensure_cache()
    var candidates: Array = _by_animation.get(String(animation_id), [])
    for value in candidates:
        var binding := value as ProductionAnimationBinding
        if binding != null and binding.mode_id == mode_id:
            return binding
    if mode_id != &"":
        for value in candidates:
            var binding := value as ProductionAnimationBinding
            if binding != null and binding.mode_id == &"":
                return binding
    return candidates[0] as ProductionAnimationBinding if not candidates.is_empty() else null

func bindings_for_move(move_id: StringName, domain_filter: int = -1) -> Array[ProductionAnimationBinding]:
    _ensure_cache()
    var out: Array[ProductionAnimationBinding] = []
    for value in _by_move.get(String(move_id), []):
        var binding := value as ProductionAnimationBinding
        if binding != null and (domain_filter < 0 or binding.domain == domain_filter):
            out.append(binding)
    return out

func first_binding_for_move(move_id: StringName, domain_filter: int = -1) -> ProductionAnimationBinding:
    var values := bindings_for_move(move_id, domain_filter)
    return values[0] if not values.is_empty() else null

func bindings_for_entity(entity_id: StringName, domain_filter: int = -1) -> Array[ProductionAnimationBinding]:
    _ensure_cache()
    var out: Array[ProductionAnimationBinding] = []
    for value in _by_entity.get(String(entity_id), []):
        var binding := value as ProductionAnimationBinding
        if binding != null and (domain_filter < 0 or binding.domain == domain_filter):
            out.append(binding)
    return out

func first_binding_for_entity(entity_id: StringName, domain_filter: int = -1) -> ProductionAnimationBinding:
    var values := bindings_for_entity(entity_id, domain_filter)
    return values[0] if not values.is_empty() else null

func has_animation(animation_id: StringName, mode_id: StringName = &"") -> bool:
    return binding_for_animation(animation_id, mode_id) != null

func has_mode(mode_id: StringName) -> bool:
    _ensure_cache()
    return _modes.has(String(mode_id))

func status_counts() -> Dictionary:
    var counts := {"GREEN": 0, "YELLOW": 0, "RED": 0}
    for binding: ProductionAnimationBinding in bindings:
        var key := String(binding.status)
        if not counts.has(key): counts[key] = 0
        counts[key] = int(counts[key]) + 1
    return counts

func _ensure_cache() -> void:
    if not _cache_ready: rebuild_cache()
