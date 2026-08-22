# Responsibility: Small deterministic Match/Round state machine ticked only by BattleSimulation.
# Owns: round timer, round score, round result, post-round countdown, pending/final participant winner.
# Does NOT own: Fighter internals, projectile arrays, input devices, HUD, wall-clock time, replay recording.
class_name RoundController
extends RefCounted

enum State {
    ROUND_ACTIVE,
    POST_ROUND,
    MATCH_OVER,
}

enum RoundResult {
    NONE,
    P1_WIN,
    P2_WIN,
    DRAW,
}

enum Participant {
    NONE,
    P1,
    P2,
}

enum PostRoundAction {
    NONE,
    RESET_ROUND,
    MATCH_OVER_REACHED,
}

var rules: MatchRulesData
var state: State = State.ROUND_ACTIVE
var round_number: int = 1
var p1_round_wins: int = 0
var p2_round_wins: int = 0
var round_timer_remaining_frames: int = 0
var post_round_remaining_frames: int = 0
var round_result: RoundResult = RoundResult.NONE
var pending_match_winner: Participant = Participant.NONE
var match_winner: Participant = Participant.NONE

func configure(p_rules: MatchRulesData) -> bool:
    rules = p_rules if p_rules != null else MatchRulesData.versus_defaults()
    if not rules.is_valid():
        push_error("RoundController rejected invalid MatchRulesData")
        return false
    reset_match()
    return true

func reset_match() -> void:
    state = State.ROUND_ACTIVE
    round_number = 1
    p1_round_wins = 0
    p2_round_wins = 0
    round_timer_remaining_frames = rules.round_timer_frames if rules != null and rules.timer_enabled else 0
    post_round_remaining_frames = 0
    round_result = RoundResult.NONE
    pending_match_winner = Participant.NONE
    match_winner = Participant.NONE

# Called exactly once after all authoritative combat results for an active simulation tick have applied.
# frozen_at_tick_start is the same global gameplay-hitstop fact used by Fighter/Projectile timelines.
func evaluate_active_tick(
    p1_is_ko: bool,
    p2_is_ko: bool,
    p1_hp: int,
    p2_hp: int,
    frozen_at_tick_start: bool
) -> bool:
    if state != State.ROUND_ACTIVE or rules == null:
        return false

    # KO has strict priority over timeout and is evaluated only after all same-frame outcomes apply.
    if p1_is_ko or p2_is_ko:
        if p1_is_ko and p2_is_ko:
            _enter_post_round(RoundResult.DRAW)
        elif p1_is_ko:
            _enter_post_round(RoundResult.P2_WIN)
        else:
            _enter_post_round(RoundResult.P1_WIN)
        return true

    if rules.timer_enabled and not frozen_at_tick_start:
        round_timer_remaining_frames = maxi(0, round_timer_remaining_frames - 1)
        if round_timer_remaining_frames <= 0:
            if p1_hp > p2_hp:
                _enter_post_round(RoundResult.P1_WIN)
            elif p2_hp > p1_hp:
                _enter_post_round(RoundResult.P2_WIN)
            else:
                _enter_post_round(RoundResult.DRAW)
            return true
    return false

# The round-ending tick itself never decrements POST_ROUND. BattleSimulation calls this only on later ticks.
func advance_post_round() -> PostRoundAction:
    if state != State.POST_ROUND or rules == null:
        return PostRoundAction.NONE
    if post_round_remaining_frames > 0:
        post_round_remaining_frames -= 1
    if post_round_remaining_frames > 0:
        return PostRoundAction.NONE

    if pending_match_winner != Participant.NONE and rules.match_can_end:
        state = State.MATCH_OVER
        match_winner = pending_match_winner
        return PostRoundAction.MATCH_OVER_REACHED

    if rules.mode == MatchRulesData.Mode.VERSUS:
        round_number += 1
    else:
        # Training uses one stable round number; repeated KO resets are training cycles, not scored rounds.
        round_number = 1
        p1_round_wins = 0
        p2_round_wins = 0
    state = State.ROUND_ACTIVE
    round_result = RoundResult.NONE
    pending_match_winner = Participant.NONE
    match_winner = Participant.NONE
    round_timer_remaining_frames = rules.round_timer_frames if rules.timer_enabled else 0
    post_round_remaining_frames = 0
    return PostRoundAction.RESET_ROUND

func is_round_active() -> bool:
    return state == State.ROUND_ACTIVE

func is_post_round() -> bool:
    return state == State.POST_ROUND

func is_match_over() -> bool:
    return state == State.MATCH_OVER

func state_name() -> String:
    return State.keys()[state]

func round_result_name() -> String:
    return RoundResult.keys()[round_result]

func winner_name(value: Participant) -> String:
    return Participant.keys()[value]

func timer_display_seconds() -> int:
    if rules == null or not rules.timer_enabled:
        return 0
    return int(ceil(float(round_timer_remaining_frames) / 60.0))

func validate_restore_snapshot(snapshot: RoundStateSnapshot) -> bool:
    if snapshot == null or rules == null or snapshot.rules_id != rules.id:
        return false
    if snapshot.state < State.ROUND_ACTIVE or snapshot.state > State.MATCH_OVER:
        return false
    if snapshot.round_number < 1 or snapshot.p1_round_wins < 0 or snapshot.p2_round_wins < 0:
        return false
    if snapshot.round_timer_remaining_frames < 0 or snapshot.post_round_remaining_frames < 0:
        return false
    if snapshot.round_result < RoundResult.NONE or snapshot.round_result > RoundResult.DRAW:
        return false
    if snapshot.pending_match_winner < Participant.NONE or snapshot.pending_match_winner > Participant.P2:
        return false
    if snapshot.match_winner < Participant.NONE or snapshot.match_winner > Participant.P2:
        return false
    if snapshot.state == State.ROUND_ACTIVE and snapshot.round_result != RoundResult.NONE:
        return false
    if snapshot.state == State.POST_ROUND and snapshot.round_result == RoundResult.NONE:
        return false
    if snapshot.state == State.MATCH_OVER and (not rules.match_can_end or snapshot.match_winner == Participant.NONE):
        return false
    if rules.mode == MatchRulesData.Mode.TRAINING and (snapshot.p1_round_wins != 0 or snapshot.p2_round_wins != 0 or snapshot.state == State.MATCH_OVER):
        return false
    return true

func restore_snapshot(snapshot: RoundStateSnapshot) -> bool:
    if not validate_restore_snapshot(snapshot):
        push_error("Round snapshot restore rejected: rules identity or state invariant mismatch")
        return false
    state = snapshot.state
    round_number = snapshot.round_number
    p1_round_wins = snapshot.p1_round_wins
    p2_round_wins = snapshot.p2_round_wins
    round_timer_remaining_frames = snapshot.round_timer_remaining_frames
    post_round_remaining_frames = snapshot.post_round_remaining_frames
    round_result = snapshot.round_result
    pending_match_winner = snapshot.pending_match_winner
    match_winner = snapshot.match_winner
    return true

func capture_snapshot() -> RoundStateSnapshot:
    var snapshot := RoundStateSnapshot.new()
    snapshot.rules_id = rules.id if rules != null else &""
    snapshot.state = state
    snapshot.round_number = round_number
    snapshot.p1_round_wins = p1_round_wins
    snapshot.p2_round_wins = p2_round_wins
    snapshot.round_timer_remaining_frames = round_timer_remaining_frames
    snapshot.post_round_remaining_frames = post_round_remaining_frames
    snapshot.round_result = round_result
    snapshot.pending_match_winner = pending_match_winner
    snapshot.match_winner = match_winner
    return snapshot

func _enter_post_round(result: RoundResult) -> void:
    round_result = result
    if rules.mode == MatchRulesData.Mode.VERSUS:
        if result == RoundResult.P1_WIN:
            p1_round_wins += 1
        elif result == RoundResult.P2_WIN:
            p2_round_wins += 1
        if rules.match_can_end:
            if p1_round_wins >= rules.rounds_to_win:
                pending_match_winner = Participant.P1
            elif p2_round_wins >= rules.rounds_to_win:
                pending_match_winner = Participant.P2
    else:
        p1_round_wins = 0
        p2_round_wins = 0
        pending_match_winner = Participant.NONE
    state = State.POST_ROUND
    post_round_remaining_frames = rules.post_round_frames
