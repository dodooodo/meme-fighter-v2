# Read-only interpretation of authoritative Fighter state into presentation keys.
class_name FighterPresentationResolver
extends RefCounted

static func resolve_animation(fighter: Fighter, data: CharacterPresentationData) -> StringName:
    if fighter == null or data == null:
        return PresentationAnimationIds.IDLE
    var state := fighter.state_machine.state
    if state in [FighterStateMachine.State.GROUND_ATTACK, FighterStateMachine.State.AIR_ATTACK, FighterStateMachine.State.THROW]:
        var move_id := fighter.move_runner.current_move_id()
        if move_id != &"":
            return data.animation_for_move(move_id, PresentationAnimationIds.ATTACK_FALLBACK)
    return data.animation_for_state(state_key_for_fighter(fighter), PresentationAnimationIds.IDLE)

static func state_key_for_fighter(fighter: Fighter) -> StringName:
    if fighter == null:
        return PresentationAnimationIds.IDLE
    match fighter.state_machine.state:
        FighterStateMachine.State.IDLE:
            return PresentationAnimationIds.IDLE
        FighterStateMachine.State.WALK_FORWARD:
            return PresentationAnimationIds.WALK_FORWARD
        FighterStateMachine.State.WALK_BACK:
            return PresentationAnimationIds.WALK_BACK
        FighterStateMachine.State.CROUCH:
            return PresentationAnimationIds.CROUCH
        FighterStateMachine.State.CHARGE:
            return PresentationAnimationIds.CHARGE
        FighterStateMachine.State.JUMP, FighterStateMachine.State.AIR_ATTACK:
            return PresentationAnimationIds.JUMP
        FighterStateMachine.State.LANDING:
            return PresentationAnimationIds.LANDING
        FighterStateMachine.State.GUARD:
            return PresentationAnimationIds.GUARD_CROUCH if fighter.state_machine.guard_posture == FighterStateMachine.GuardPosture.CROUCHING else PresentationAnimationIds.GUARD_STAND
        FighterStateMachine.State.HITSTUN:
            return PresentationAnimationIds.HITSTUN
        FighterStateMachine.State.BLOCKSTUN:
            return PresentationAnimationIds.BLOCKSTUN
        FighterStateMachine.State.THROWN:
            return PresentationAnimationIds.THROWN
        FighterStateMachine.State.KNOCKDOWN:
            return PresentationAnimationIds.KNOCKDOWN
        FighterStateMachine.State.GETUP:
            return PresentationAnimationIds.GETUP
        FighterStateMachine.State.KO:
            return PresentationAnimationIds.KO
        FighterStateMachine.State.DASH_FORWARD:
            return PresentationAnimationIds.DASH_FORWARD
        FighterStateMachine.State.BACKSTEP:
            return PresentationAnimationIds.BACKSTEP
        _:
            return PresentationAnimationIds.IDLE
