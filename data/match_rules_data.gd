# Responsibility: Immutable deterministic rules configuration for one local battle mode.
# Owns: stable rules identity and round/match timing/reset policy.
# Does NOT own: mutable round state, Fighter state, input, presentation, replay runtime.
class_name MatchRulesData
extends Resource

enum Mode {
    VERSUS,
    TRAINING,
}

@export_group("Identity")
@export var id: StringName = &""
@export var mode: Mode = Mode.VERSUS

@export_group("Round / Match")
@export_range(0, 99, 1) var rounds_to_win: int = 2
@export var timer_enabled: bool = true
@export_range(0, 36000, 1) var round_timer_frames: int = 5940
@export_range(0, 3600, 1) var post_round_frames: int = 90
@export var match_can_end: bool = true
@export var reset_meter_each_round: bool = true

func is_valid() -> bool:
    if id == &"" or rounds_to_win < 0 or round_timer_frames < 0 or post_round_frames < 0:
        return false
    match mode:
        Mode.VERSUS:
            return rounds_to_win > 0 and match_can_end and (not timer_enabled or round_timer_frames > 0)
        Mode.TRAINING:
            return not timer_enabled and not match_can_end
    return false

static func versus_defaults() -> MatchRulesData:
    var rules := MatchRulesData.new()
    rules.id = &"versus"
    rules.mode = Mode.VERSUS
    rules.rounds_to_win = 2
    rules.timer_enabled = true
    rules.round_timer_frames = 5940
    rules.post_round_frames = 90
    rules.match_can_end = true
    rules.reset_meter_each_round = true
    return rules

static func training_defaults() -> MatchRulesData:
    var rules := MatchRulesData.new()
    rules.id = &"training"
    rules.mode = Mode.TRAINING
    rules.rounds_to_win = 0
    rules.timer_enabled = false
    rules.round_timer_frames = 0
    rules.post_round_frames = 60
    rules.match_can_end = false
    rules.reset_meter_each_round = true
    return rules
