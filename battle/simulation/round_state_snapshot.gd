# Responsibility: Typed snapshot value for all future-affecting RoundController mutable gameplay state.
# Owns: stable rules ID plus round/match counters, timers, result, pending/final participant winner.
# Does NOT own: MatchRulesData Resource pointers, HUD state, replay state, presentation events.
class_name RoundStateSnapshot
extends RefCounted

var rules_id: StringName = &""
var state: int = RoundController.State.ROUND_ACTIVE
var round_number: int = 1
var p1_round_wins: int = 0
var p2_round_wins: int = 0
var round_timer_remaining_frames: int = 0
var post_round_remaining_frames: int = 0
var round_result: int = RoundController.RoundResult.NONE
var pending_match_winner: int = RoundController.Participant.NONE
var match_winner: int = RoundController.Participant.NONE
