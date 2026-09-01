# Responsibility: Canonical same-simulation-tick contact priority using one pre-apply state.
# Owns: active-strike-vs-throw suppression and simultaneous normal-throw auto-tech classification.
# Does NOT own: damage, HP, state mutation, geometry discovery, character-specific rules.
class_name SameTickArbitrator
extends RefCounted

static func arbitrate(
    strike_results: Array[HitResult],
    throw_a: HitResult,
    throw_b: HitResult,
    fighter_a: Fighter,
    fighter_b: Fighter
) -> Dictionary:
    var suppress_a := _active_strike_hits_throw_attacker(strike_results, throw_a)
    var suppress_b := _active_strike_hits_throw_attacker(strike_results, throw_b)
    var normal_auto_tech := false
    if not suppress_a and not suppress_b and throw_a != null and throw_b != null:
        var move_a := fighter_a.move_registry.get_move(throw_a.move_id) if fighter_a != null else null
        var move_b := fighter_b.move_registry.get_move(throw_b.move_id) if fighter_b != null else null
        normal_auto_tech = (
            move_a != null and move_b != null
            and move_a.throw_kind == MoveData.ThrowKind.NORMAL_THROW
            and move_b.throw_kind == MoveData.ThrowKind.NORMAL_THROW
        )
    return {
        "throw_a": null if suppress_a or normal_auto_tech else throw_a,
        "throw_b": null if suppress_b or normal_auto_tech else throw_b,
        "normal_auto_tech": normal_auto_tech,
    }

static func _active_strike_hits_throw_attacker(strike_results: Array[HitResult], throw_result: HitResult) -> bool:
    if throw_result == null:
        return false
    for result: HitResult in strike_results:
        if result == null:
            continue
        if result.attack_source_kind != HitResult.AttackSourceKind.FIGHTER_BODY:
            continue
        if result.attacker_id != throw_result.defender_id or result.defender_id != throw_result.attacker_id:
            continue
        if result.result_type in [HitResult.ResultType.HIT, HitResult.ResultType.ARMOR, HitResult.ResultType.COUNTERED]:
            return true
    return false
