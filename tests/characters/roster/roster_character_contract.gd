# Shared Gate 2 roster gameplay contract. Each concrete test adds its unique mechanic assertions.
class_name RosterCharacterContract
extends RefCounted

static func run_common(t: TestAssert, character_id: StringName, expected_hp: int, expected_active_prefix: String = "") -> CharacterData:
    var character := RosterRegistry.character_by_id(character_id)
    t.that(character != null, "%s resolves through active RosterRegistry" % String(character_id))
    if character == null:
        return null
    t.equal(character.id, character_id, "%s active CharacterData identity matches roster" % String(character_id))
    t.equal(character.max_hp, expected_hp, "%s canonical Alpha HP" % String(character_id))
    t.that(character.walk_forward_units_per_tick > 0 and character.walk_back_units_per_tick > 0, "%s canonical ground movement is authored" % String(character_id))
    t.that(character.dash_move_frames > 0 and character.dash_speed_units_per_tick > 0 and character.backstep_move_frames > 0, "%s dash/backstep identity is authored" % String(character_id))
    if expected_active_prefix != "":
        t.that(character.resource_path.begins_with(expected_active_prefix), "%s test uses active runtime CharacterData path" % String(character_id))
    t.that(character.mechanics != null, "%s CharacterMechanicsData resolves" % String(character_id))
    t.that(character.move_set != null, "%s active MoveSet resolves" % String(character_id))
    if character.move_set == null:
        return character
    var registry := MoveRegistry.new()
    t.that(registry.configure(character.move_set), "%s MoveSet validates" % String(character_id))
    for move_id: StringName in [MoveIds.STAND_LIGHT, MoveIds.STAND_HEAVY, MoveIds.CROUCH_LOW, MoveIds.AIR_ATTACK, MoveIds.GROUND_THROW, MoveIds.SPECIAL_NEUTRAL, MoveIds.ULTIMATE]:
        t.that(registry.has_move(move_id), "%s required move resolves: %s" % [String(character_id), String(move_id)])
    var special := registry.get_move(MoveIds.SPECIAL_NEUTRAL)
    t.that(special != null and special.charge_special_data != null and special.charge_special_data.is_valid(), "%s Special charge entry resolves" % String(character_id))
    if special != null and special.charge_special_data != null:
        for level_id: StringName in [special.charge_special_data.level_1_move_id, special.charge_special_data.level_2_move_id, special.charge_special_data.level_3_move_id]:
            t.that(registry.has_move(level_id), "%s Special charge level resolves: %s" % [String(character_id), String(level_id)])
    for move: MoveData in character.move_set.moves:
        if move == null:
            continue
        for cancel: CancelWindowData in move.cancel_windows:
            if cancel == null:
                continue
            for target_id: StringName in cancel.allowed_target_move_ids:
                t.that(registry.has_move(target_id), "%s cancel target resolves: %s -> %s" % [String(character_id), String(move.id), String(target_id)])
    return character

static func registry_for(character: CharacterData) -> MoveRegistry:
    var registry := MoveRegistry.new()
    if character != null:
        registry.configure(character.move_set)
    return registry

static func resource_by_id(character: CharacterData, resource_id: StringName) -> FighterResourceData:
    if character == null or character.mechanics == null:
        return null
    for data: FighterResourceData in character.mechanics.resources:
        if data != null and data.resource_id == resource_id:
            return data
    return null

static func status_by_id(character: CharacterData, status_id: StringName) -> StatusEffectData:
    if character == null or character.mechanics == null:
        return null
    for data: StatusEffectData in character.mechanics.statuses:
        if data != null and data.id == status_id:
            return data
    return null

static func mode_by_id(character: CharacterData, mode_id: StringName) -> ModeData:
    if character == null or character.mechanics == null:
        return null
    for data: ModeData in character.mechanics.modes:
        if data != null and data.mode_id == mode_id:
            return data
    return null

static func all_effects(move: MoveData) -> Array[GameplayEffectData]:
    var out: Array[GameplayEffectData] = []
    if move == null:
        return out
    out.append_array(move.on_start_effects)
    out.append_array(move.on_complete_effects)
    out.append_array(move.on_hit_effects)
    out.append_array(move.on_block_effects)
    for hit: MoveHitData in move.hits:
        if hit != null:
            out.append_array(hit.on_hit_effects)
            out.append_array(hit.on_block_effects)
    return out

static func effect_of_type(move: MoveData, effect_type: int) -> GameplayEffectData:
    for effect: GameplayEffectData in all_effects(move):
        if effect != null and effect.type == effect_type:
            return effect
    return null

static func has_cancel_target(move: MoveData, target_id: StringName, condition: int = -1) -> bool:
    if move == null:
        return false
    for window: CancelWindowData in move.cancel_windows:
        if window == null or not window.allowed_target_move_ids.has(target_id):
            continue
        if condition < 0 or window.condition == condition:
            return true
    return false
