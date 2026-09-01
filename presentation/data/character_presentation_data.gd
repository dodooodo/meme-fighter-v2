# Presentation-only immutable character visual configuration.
# Never referenced by BattleSimulation, BattleSnapshot, BattleStateHasher, or Replay gameplay truth.
class_name CharacterPresentationData
extends Resource

@export var character_id: StringName = &""
@export var display_name: String = ""
@export var fighter_visual_scene: PackedScene
@export var visual_offset_pixels: Vector2 = Vector2.ZERO
@export var visual_scale: float = 1.0
@export var placeholder_color: Color = Color.WHITE
@export var state_bindings: Array[StatePresentationBinding] = []
@export var move_bindings: Array[MovePresentationBinding] = []
@export var projectile_bindings: Array[ProjectilePresentationBinding] = []
@export var mode_bindings: Array[ModePresentationBinding] = []
@export var ultimate_bindings: Array[UltimatePresentationBinding] = []
@export var effect_bindings: Array[EffectPresentationBinding] = []
@export var attachment_bindings: Array[AttachmentPresentationBinding] = []
@export var socket_offsets: Dictionary = {}
@export var production_asset_binding: ProductionCharacterAssetBinding

var _state_lookup: Dictionary = {}
var _move_lookup: Dictionary = {}
var _projectile_lookup: Dictionary = {}
var _mode_lookup: Dictionary = {}
var _ultimate_lookup: Dictionary = {}
var _effect_lookup: Dictionary = {}
var _attachment_lookup: Dictionary = {}
var _move_animation_keys: Dictionary = {}
var _cache_ready: bool = false

func validate(expected_character_id: StringName = &"") -> PackedStringArray:
    var errors := PackedStringArray()
    if character_id == &"":
        errors.append("character_id must be non-empty")
    if expected_character_id != &"" and character_id != expected_character_id:
        errors.append("presentation character_id mismatch: expected %s got %s" % [String(expected_character_id), String(character_id)])
    if display_name.strip_edges().is_empty():
        errors.append("display_name must be non-empty")
    if visual_scale <= 0.0:
        errors.append("visual_scale must be > 0")
    _validate_bindings(errors)
    if production_asset_binding != null:
        if production_asset_binding.character_id != character_id:
            errors.append("production asset character_id mismatch")
        errors.append_array(production_asset_binding.validate())
    return errors

func rebuild_cache() -> bool:
    var errors := validate()
    if not errors.is_empty():
        return false
    _state_lookup.clear()
    _move_lookup.clear()
    _projectile_lookup.clear()
    _mode_lookup.clear()
    _ultimate_lookup.clear()
    _effect_lookup.clear()
    _attachment_lookup.clear()
    _move_animation_keys.clear()
    for binding: StatePresentationBinding in state_bindings:
        if not _state_lookup.has(binding.state_key):
            _state_lookup[binding.state_key] = []
        (_state_lookup[binding.state_key] as Array).append(binding)
    for binding: MovePresentationBinding in move_bindings:
        if not _move_lookup.has(binding.move_id):
            _move_lookup[binding.move_id] = []
        (_move_lookup[binding.move_id] as Array).append(binding)
        _move_animation_keys[binding.animation_key] = true
    for binding: ProjectilePresentationBinding in projectile_bindings:
        _projectile_lookup[binding.projectile_id] = binding
    for binding: ModePresentationBinding in mode_bindings:
        _mode_lookup[binding.mode_id] = binding
    for binding: UltimatePresentationBinding in ultimate_bindings:
        _ultimate_lookup[binding.ultimate_id] = binding
    for binding: EffectPresentationBinding in effect_bindings:
        _effect_lookup[binding.effect_id] = binding
    for binding: AttachmentPresentationBinding in attachment_bindings:
        _attachment_lookup[binding.attachment_id] = binding
    _cache_ready = true
    return true

func animation_for_state(state_key: StringName, fallback: StringName = &"idle", resources: FighterResourceComponent = null) -> StringName:
    _ensure_cache()
    var values: Variant = _state_lookup.get(state_key, [])
    if values is Array and not values.is_empty():
        return _resolve_resource_variant(values, fallback, resources)
    if production_asset_binding != null and production_asset_binding.has_animation(state_key):
        return state_key
    return fallback

func animation_for_move(move_id: StringName, fallback: StringName = &"attack", resources: FighterResourceComponent = null) -> StringName:
    _ensure_cache()
    var values: Variant = _move_lookup.get(move_id, [])
    if values is Array and not values.is_empty():
        return _resolve_resource_variant(values, fallback, resources)
    if production_asset_binding != null and production_asset_binding.has_animation(move_id):
        return move_id
    return fallback

# True when an animation key is driven by a Move phase timeline rather than by
# animation playback. Data-driven so Courage-style variants stay timeline-driven
# without adding character-ID or animation-name branching.
func is_move_driven_animation(animation_key: StringName) -> bool:
    _ensure_cache()
    return _move_animation_keys.has(animation_key)

func projectile_binding(projectile_id: StringName) -> ProjectilePresentationBinding:
    _ensure_cache()
    return _projectile_lookup.get(projectile_id, null) as ProjectilePresentationBinding

func mode_binding(mode_id: StringName) -> ModePresentationBinding:
    _ensure_cache()
    return _mode_lookup.get(mode_id, null) as ModePresentationBinding

func ultimate_binding(ultimate_id: StringName = &"ultimate") -> UltimatePresentationBinding:
    _ensure_cache()
    return _ultimate_lookup.get(ultimate_id, null) as UltimatePresentationBinding

func effect_binding(effect_id: StringName) -> EffectPresentationBinding:
    _ensure_cache()
    return _effect_lookup.get(effect_id, null) as EffectPresentationBinding

func attachment_binding(attachment_id: StringName) -> AttachmentPresentationBinding:
    _ensure_cache()
    return _attachment_lookup.get(attachment_id, null) as AttachmentPresentationBinding

func effects_for_move(move_id: StringName, trigger_event: int = -1) -> Array[EffectPresentationBinding]:
    _ensure_cache()
    var out: Array[EffectPresentationBinding] = []
    for binding: EffectPresentationBinding in effect_bindings:
        if binding.move_id != &"" and binding.move_id != move_id:
            continue
        if trigger_event >= 0 and int(binding.trigger_event) != trigger_event:
            continue
        out.append(binding)
    return out

func _ensure_cache() -> void:
    if not _cache_ready:
        rebuild_cache()

func _validate_bindings(errors: PackedStringArray) -> void:
    _validate_state_bindings(errors)
    _validate_move_bindings(errors)
    _validate_projectile_bindings(errors)
    _validate_mode_bindings(errors)
    _validate_ultimate_bindings(errors)
    _validate_effect_bindings(errors)
    _validate_attachment_bindings(errors)

func _validate_state_bindings(errors: PackedStringArray) -> void:
    var grouped: Dictionary = {}
    for binding: StatePresentationBinding in state_bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid state presentation binding")
            continue
        if not grouped.has(binding.state_key):
            grouped[binding.state_key] = []
        (grouped[binding.state_key] as Array).append(binding)
    _validate_resource_variant_groups(grouped, "state", "duplicate state binding", errors)

func _validate_move_bindings(errors: PackedStringArray) -> void:
    var grouped: Dictionary = {}
    for binding: MovePresentationBinding in move_bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid move presentation binding")
            continue
        if not grouped.has(binding.move_id):
            grouped[binding.move_id] = []
        (grouped[binding.move_id] as Array).append(binding)
    _validate_resource_variant_groups(grouped, "move", "duplicate move binding", errors)

func _validate_resource_variant_groups(grouped: Dictionary, binding_kind: String, duplicate_error: String, errors: PackedStringArray) -> void:
    for key: StringName in grouped:
        var bindings: Array = grouped[key]
        var fallback_count := 0
        var conditioned: Array = []
        for binding: Variant in bindings:
            if not binding.has_resource_condition():
                fallback_count += 1
            else:
                conditioned.append(binding)
        if fallback_count > 1:
            errors.append("%s: %s" % [duplicate_error, String(key)])
        for index in range(conditioned.size()):
            var current: Variant = conditioned[index]
            for other_index in range(index + 1, conditioned.size()):
                var other: Variant = conditioned[other_index]
                if current.resource_id != other.resource_id:
                    errors.append("ambiguous %s resource bindings: %s" % [binding_kind, String(key)])
                    continue
                if current.resource_min_value <= other.resource_max_value and other.resource_min_value <= current.resource_max_value:
                    errors.append("overlapping %s resource bindings: %s" % [binding_kind, String(key)])

func _resolve_resource_variant(bindings_value: Variant, fallback: StringName, resources: FighterResourceComponent) -> StringName:
    if not (bindings_value is Array):
        return fallback
    var unconditional: Variant = null
    for binding: Variant in bindings_value:
        if binding.has_resource_condition():
            if binding.matches_resources(resources):
                return binding.animation_key
        else:
            unconditional = binding
    return unconditional.animation_key if unconditional != null else fallback

func _validate_projectile_bindings(errors: PackedStringArray) -> void:
    var seen: Dictionary = {}
    for binding: ProjectilePresentationBinding in projectile_bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid projectile presentation binding")
            continue
        if seen.has(binding.projectile_id):
            errors.append("duplicate projectile binding: %s" % String(binding.projectile_id))
        seen[binding.projectile_id] = true

func _validate_mode_bindings(errors: PackedStringArray) -> void:
    var seen: Dictionary = {}
    for binding: ModePresentationBinding in mode_bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid mode presentation binding")
            continue
        if seen.has(binding.mode_id):
            errors.append("duplicate mode binding: %s" % String(binding.mode_id))
        seen[binding.mode_id] = true

func _validate_ultimate_bindings(errors: PackedStringArray) -> void:
    var seen: Dictionary = {}
    for binding: UltimatePresentationBinding in ultimate_bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid ultimate presentation binding")
            continue
        if seen.has(binding.ultimate_id):
            errors.append("duplicate ultimate binding: %s" % String(binding.ultimate_id))
        seen[binding.ultimate_id] = true

func _validate_effect_bindings(errors: PackedStringArray) -> void:
    var seen: Dictionary = {}
    for binding: EffectPresentationBinding in effect_bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid effect presentation binding")
            continue
        if seen.has(binding.effect_id):
            errors.append("duplicate effect binding: %s" % String(binding.effect_id))
        seen[binding.effect_id] = true

func _validate_attachment_bindings(errors: PackedStringArray) -> void:
    var seen: Dictionary = {}
    for binding: AttachmentPresentationBinding in attachment_bindings:
        if binding == null or not binding.is_valid():
            errors.append("invalid attachment presentation binding")
            continue
        if seen.has(binding.attachment_id):
            errors.append("duplicate attachment binding: %s" % String(binding.attachment_id))
        seen[binding.attachment_id] = true
