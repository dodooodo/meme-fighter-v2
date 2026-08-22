# Responsibility: Match-mode selection used only to choose scene-level InputSource wiring.
# Does NOT own gameplay rules, Fighter state, damage, meter, round data, or presentation authority.
class_name BattleMode
extends RefCounted

enum Mode {
    LOCAL_2P,
    VS_CPU,
}

static func display_name(mode: int) -> String:
    return "1P VS CPU" if mode == Mode.VS_CPU else "2P LOCAL"
