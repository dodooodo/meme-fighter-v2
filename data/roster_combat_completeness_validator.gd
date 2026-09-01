# Gate 2 gameplay-graph validator. Tooling only: resolves the active RosterRegistry graph.
# This may iterate roster IDs; authoritative gameplay core remains character-agnostic.
class_name RosterCombatCompletenessValidator
extends RefCounted

const REQUIRED_CORE_MOVE_IDS: Array[StringName] = [
    MoveIds.STAND_LIGHT,
    MoveIds.STAND_HEAVY,
    MoveIds.CROUCH_LOW,
    MoveIds.AIR_ATTACK,
    MoveIds.GROUND_THROW,
    MoveIds.SPECIAL_NEUTRAL,
    MoveIds.ULTIMATE,
]

func validate_all() -> Dictionary:
    var results: Dictionary = {}
    for entry: Dictionary in RosterRegistry.ENTRIES:
        var character_id := entry.get("id", &"") as StringName
        var character := entry.get("character", null) as CharacterData
        results[String(character_id)] = validate_character(character_id, character)
    return results

func green_count() -> int:
    var count := 0
    for errors: Variant in validate_all().values():
        if errors is PackedStringArray and (errors as PackedStringArray).is_empty():
            count += 1
    return count

func validate_character(expected_id: StringName, character: CharacterData) -> PackedStringArray:
    var errors := PackedStringArray()
    if character == null:
        errors.append("Active CharacterData missing")
        return errors
    if character.id != expected_id:
        errors.append("Active CharacterData id mismatch: expected=%s actual=%s" % [String(expected_id), String(character.id)])
    if character.move_set == null:
        errors.append("Active MoveSet missing")
        return errors
    if character.mechanics == null:
        errors.append("CharacterMechanicsData missing")

    var registry := MoveRegistry.new()
    if not registry.configure(character.move_set):
        for message: String in registry.validation_errors():
            errors.append(message)
        return errors

    for move_id: StringName in REQUIRED_CORE_MOVE_IDS:
        if not registry.has_move(move_id):
            errors.append("Required move missing: %s" % String(move_id))

    var special := registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    if special == null or special.charge_special_data == null:
        errors.append("Special entry has no ChargeSpecialData")
    elif not special.charge_special_data.is_valid():
        errors.append("Special entry ChargeSpecialData invalid")
    else:
        for level_id: StringName in [
            special.charge_special_data.level_1_move_id,
            special.charge_special_data.level_2_move_id,
            special.charge_special_data.level_3_move_id,
        ]:
            if not registry.has_move(level_id):
                errors.append("Charge level move missing: %s" % String(level_id))

    var resource_ids: Dictionary = {}
    var status_ids: Dictionary = {}
    var mode_ids: Dictionary = {}
    if character.mechanics != null:
        for resource: FighterResourceData in character.mechanics.resources:
            if resource == null or resource.resource_id == &"":
                errors.append("Invalid FighterResourceData")
            else:
                resource_ids[resource.resource_id] = true
        for status: StatusEffectData in character.mechanics.statuses:
            if status == null or status.id == &"":
                errors.append("Invalid StatusEffectData")
            else:
                status_ids[status.id] = true
        for mode: ModeData in character.mechanics.modes:
            if mode == null or mode.mode_id == &"":
                errors.append("Invalid ModeData")
                continue
            mode_ids[mode.mode_id] = true
            if mode.exit_when_resource_zero_id != &"" and not resource_ids.has(mode.exit_when_resource_zero_id):
                errors.append("Mode exit resource missing: %s" % String(mode.exit_when_resource_zero_id))
            if mode.exit_move_id != &"" and not registry.has_move(mode.exit_move_id):
                errors.append("Mode exit move missing: %s" % String(mode.exit_move_id))
            if mode.finisher_enabled:
                if mode.finisher_resource_id != &"" and not resource_ids.has(mode.finisher_resource_id):
                    errors.append("Mode finisher resource missing: %s" % String(mode.finisher_resource_id))
                if mode.finisher_tiers.is_empty() and (mode.finisher_move_id == &"" or not registry.has_move(mode.finisher_move_id)):
                    errors.append("Mode finisher move missing: %s" % String(mode.finisher_move_id))
                var seen_finisher_values: Dictionary = {}
                for tier: ModeFinisherTierData in mode.finisher_tiers:
                    if tier == null or not tier.is_valid() or not registry.has_move(tier.move_id):
                        errors.append("Invalid mode finisher tier")
                    elif seen_finisher_values.has(tier.resource_value):
                        errors.append("Duplicate mode finisher resource tier: %d" % tier.resource_value)
                    else:
                        seen_finisher_values[tier.resource_value] = true
            for override: ModeMoveOverrideData in mode.move_overrides:
                if override == null:
                    errors.append("Null ModeMoveOverrideData")
                elif not registry.has_move(override.replacement_move_id):
                    errors.append("Mode override move missing: %s" % String(override.replacement_move_id))
        _validate_mechanics_cross_refs(character.mechanics, resource_ids, status_ids, mode_ids, errors)

    for move: MoveData in character.move_set.moves:
        if move == null:
            continue
        _validate_move_refs(move, registry, resource_ids, status_ids, mode_ids, errors)
    return errors

func _validate_mechanics_cross_refs(mechanics: CharacterMechanicsData, resource_ids: Dictionary, status_ids: Dictionary, mode_ids: Dictionary, errors: PackedStringArray) -> void:
    if mechanics.panic_exit_status_id != &"" and not status_ids.has(mechanics.panic_exit_status_id):
        errors.append("Panic Exit status missing: %s" % String(mechanics.panic_exit_status_id))
    if mechanics.successful_hit_grants_status_id != &"" and not status_ids.has(mechanics.successful_hit_grants_status_id):
        errors.append("Successful-hit status missing: %s" % String(mechanics.successful_hit_grants_status_id))
    if mechanics.last_stand_mode_id != &"" and not mode_ids.has(mechanics.last_stand_mode_id):
        errors.append("Last Stand mode missing: %s" % String(mechanics.last_stand_mode_id))
    if mechanics.last_stand_resolve_resource_id != &"" and not resource_ids.has(mechanics.last_stand_resolve_resource_id):
        errors.append("Last Stand resource missing: %s" % String(mechanics.last_stand_resolve_resource_id))
    if mechanics.heavy_knockdown_resource_id != &"" and not resource_ids.has(mechanics.heavy_knockdown_resource_id):
        errors.append("Heavy-KD resource missing: %s" % String(mechanics.heavy_knockdown_resource_id))

func _validate_move_refs(move: MoveData, registry: MoveRegistry, resource_ids: Dictionary, status_ids: Dictionary, mode_ids: Dictionary, errors: PackedStringArray) -> void:
    if move.resource_cost_id != &"" and not resource_ids.has(move.resource_cost_id):
        errors.append("%s resource cost missing: %s" % [String(move.id), String(move.resource_cost_id)])
    if move.activation_resource_cashout_id != &"" and not resource_ids.has(move.activation_resource_cashout_id):
        errors.append("%s activation cashout resource missing: %s" % [String(move.id), String(move.activation_resource_cashout_id)])
    if move.counter_data != null and move.counter_data.success_move_id != &"" and not registry.has_move(move.counter_data.success_move_id):
        errors.append("%s counter success move missing: %s" % [String(move.id), String(move.counter_data.success_move_id)])
    for cancel: CancelWindowData in move.cancel_windows:
        if cancel == null:
            errors.append("%s has null CancelWindowData" % String(move.id))
            continue
        if cancel.resource_condition_id != &"" and not resource_ids.has(cancel.resource_condition_id):
            errors.append("%s cancel resource missing: %s" % [String(move.id), String(cancel.resource_condition_id)])
        if cancel.movement_resource_cost_id != &"" and not resource_ids.has(cancel.movement_resource_cost_id):
            errors.append("%s movement cancel resource missing: %s" % [String(move.id), String(cancel.movement_resource_cost_id)])
        for target_id: StringName in cancel.allowed_target_move_ids:
            if not registry.has_move(target_id):
                errors.append("%s cancel target missing: %s" % [String(move.id), String(target_id)])
    var effects: Array[GameplayEffectData] = []
    effects.append_array(move.on_start_effects)
    effects.append_array(move.on_complete_effects)
    effects.append_array(move.on_hit_effects)
    effects.append_array(move.on_block_effects)
    for hit: MoveHitData in move.hits:
        if hit != null:
            effects.append_array(hit.on_hit_effects)
            effects.append_array(hit.on_block_effects)
    for effect: GameplayEffectData in effects:
        _validate_effect_ref(move.id, effect, resource_ids, status_ids, mode_ids, errors)

func _validate_effect_ref(move_id: StringName, effect: GameplayEffectData, resource_ids: Dictionary, status_ids: Dictionary, mode_ids: Dictionary, errors: PackedStringArray) -> void:
    if effect == null:
        errors.append("%s has null GameplayEffectData" % String(move_id))
        return
    if effect.type == GameplayEffectData.Type.APPLY_STATUS and (effect.status == null or effect.status.id == &""):
        errors.append("%s APPLY_STATUS has no StatusEffectData" % String(move_id))
    if effect.type in [GameplayEffectData.Type.GAIN_RESOURCE, GameplayEffectData.Type.SPEND_RESOURCE, GameplayEffectData.Type.SET_RESOURCE, GameplayEffectData.Type.ADD_RESOLVE]:
        if effect.id == &"" or not resource_ids.has(effect.id):
            errors.append("%s effect resource missing: %s" % [String(move_id), String(effect.id)])
    if effect.type == GameplayEffectData.Type.ENTER_MODE:
        var effect_mode_id := effect.mode.mode_id if effect.mode != null else effect.id
        if effect_mode_id == &"" or not mode_ids.has(effect_mode_id):
            errors.append("%s mode effect missing definition: %s" % [String(move_id), String(effect_mode_id)])
    if effect.type == GameplayEffectData.Type.SPAWN_AREA and (effect.area == null or effect.area.id == &""):
        errors.append("%s SPAWN_AREA has invalid AreaData" % String(move_id))
    if effect.type == GameplayEffectData.Type.SPAWN_SUMMON and (effect.summon == null or effect.summon.id == &""):
        errors.append("%s SPAWN_SUMMON has invalid SummonData" % String(move_id))
    if effect.type == GameplayEffectData.Type.SPAWN_HAZARD and (effect.hazard == null or effect.hazard.id == &""):
        errors.append("%s SPAWN_HAZARD has invalid HazardData" % String(move_id))
    if effect.type == GameplayEffectData.Type.START_SEQUENCE and (effect.sequence == null or effect.sequence.id == &""):
        errors.append("%s START_SEQUENCE has invalid SequenceData" % String(move_id))
