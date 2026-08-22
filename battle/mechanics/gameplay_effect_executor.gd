# Executes generic deterministic GameplayEffectData against authoritative runtime only.
class_name GameplayEffectExecutor
extends RefCounted

var positioning_system: PositioningSystem = PositioningSystem.new()

func execute_all(effects: Array[GameplayEffectData], attacker: Fighter, defender: Fighter, temp_entities: TemporaryEntitySystem, contact_flags: int, stage_left: int, stage_right: int) -> void:
    for effect in effects:
        if effect == null or not GameplayConditionEvaluator.matches_all(effect.conditions, attacker, defender, contact_flags, temp_entities): continue
        execute(effect, attacker, defender, temp_entities, stage_left, stage_right)

func execute(effect: GameplayEffectData, attacker: Fighter, defender: Fighter, temp_entities: TemporaryEntitySystem, stage_left: int, stage_right: int) -> void:
    if effect == null or attacker == null: return
    match effect.type:
        GameplayEffectData.Type.APPLY_STATUS:
            var status_target := attacker if effect.target == GameplayEffectData.Target.ATTACKER else defender
            if status_target != null and effect.status != null: status_target.statuses.apply(effect.status)
        GameplayEffectData.Type.REMOVE_STATUS, GameplayEffectData.Type.CONSUME_STATUS:
            var status_target := attacker if effect.target == GameplayEffectData.Target.ATTACKER else defender
            if status_target != null: status_target.statuses.remove(effect.id)
        GameplayEffectData.Type.EXTEND_STATUS_ONCE:
            var status_target := attacker if effect.target == GameplayEffectData.Target.ATTACKER else defender
            if status_target != null: status_target.statuses.extend_once(effect.id, effect.value)
        GameplayEffectData.Type.GAIN_RESOURCE:
            attacker.resources.gain(effect.id, effect.value)
        GameplayEffectData.Type.SPEND_RESOURCE:
            attacker.resources.spend(effect.id, effect.value)
        GameplayEffectData.Type.SET_RESOURCE:
            attacker.resources.set_value(effect.id, effect.value)
        GameplayEffectData.Type.ENTER_MODE:
            if effect.mode != null: attacker.mode.enter(effect.mode.mode_id, effect.mode.duration_frames, 0)
            elif effect.id != &"": attacker.mode.enter(effect.id, effect.value, 0)
        GameplayEffectData.Type.EXIT_MODE:
            attacker.mode.exit()
        GameplayEffectData.Type.SELF_DAMAGE_NONLETHAL:
            attacker.combatant.hp = maxi(1, attacker.combatant.hp - maxi(0, effect.value))
        GameplayEffectData.Type.ADD_SELF_VELOCITY:
            attacker.movement_motor.velocity_units += effect.vector_units
            attacker.movement_motor.sim_position += effect.vector_units
            attacker.movement_motor.clamp_x_to_stage()
        GameplayEffectData.Type.POSITION_EFFECT:
            positioning_system.apply(effect.positioning, attacker, defender, stage_left, stage_right)
        GameplayEffectData.Type.SPAWN_AREA:
            if temp_entities != null: temp_entities.spawn_area(attacker, effect.area)
        GameplayEffectData.Type.SPAWN_SUMMON:
            if temp_entities != null: temp_entities.spawn_summon(attacker, effect.summon)
        GameplayEffectData.Type.SPAWN_HAZARD:
            if temp_entities != null: temp_entities.spawn_hazard(attacker, effect.hazard)
        GameplayEffectData.Type.START_SEQUENCE:
            if temp_entities != null: temp_entities.spawn_sequence(attacker, effect.sequence)
        GameplayEffectData.Type.FORCE_TRIGGER_AREA:
            if temp_entities != null: temp_entities.force_trigger_owner_area(attacker.fighter_id, effect.id)
        GameplayEffectData.Type.GRANT_PANIC_EXIT:
            if effect.status != null: attacker.statuses.apply(effect.status)
            elif attacker.mechanics_runtime.panic_status_id() != &"": attacker.statuses.apply_defined(attacker.mechanics_runtime.panic_status_id())
        GameplayEffectData.Type.ADD_RESOLVE:
            attacker.resources.gain(effect.id, effect.value)
        GameplayEffectData.Type.APPLY_ARMOR_CHARGE:
            attacker.mechanics_runtime.armor_remaining_hits = maxi(attacker.mechanics_runtime.armor_remaining_hits, effect.value)
        GameplayEffectData.Type.CLEAR_ARMOR:
            attacker.mechanics_runtime.armor_remaining_hits = 0
        GameplayEffectData.Type.MODIFY_KNOCKDOWN:
            pass # HitResult reaction mutation is resolved before apply; kept as a stable data/API slot.
        GameplayEffectData.Type.FORCE_STAND:
            if defender != null: defender.enter_forced_stand(maxi(1, effect.value))
        GameplayEffectData.Type.SET_PRESENTATION_EVENT_TAG:
            pass # authoritative tag only; presentation may observe move/status/mode IDs.
