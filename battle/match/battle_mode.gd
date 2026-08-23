# Responsibility: Match-mode selection used only to choose scene-level InputSource wiring.
# Does NOT own gameplay rules, Fighter state, damage, meter, round data, or presentation authority.
class_name BattleMode
extends RefCounted

enum Mode {
    LOCAL_2P,
    VS_CPU,
    TRAINING,
    TUTORIAL,
}

static func display_name(mode: int) -> String:
    match mode:
        Mode.VS_CPU:
            return "1P VS CPU"
        Mode.TRAINING:
            return "TRAINING LAB"
        Mode.TUTORIAL:
            return "FIRST FIGHT"
        _:
            return "2P LOCAL"

static func telemetry_name(mode: int) -> String:
    match mode:
        Mode.VS_CPU:
            return "vs_cpu"
        Mode.TRAINING:
            return "training"
        Mode.TUTORIAL:
            return "tutorial"
        _:
            return "local_2p"

static func uses_training_rules(mode: int) -> bool:
    return mode in [Mode.TRAINING, Mode.TUTORIAL]
