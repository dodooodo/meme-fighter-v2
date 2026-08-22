# Responsibility: Match-mode -> desktop InputSource construction only.
# Owns: exact P1/P2 debug keyboard mappings and VS_CPU source selection.
# Does NOT own: combat rules, Fighter state, AI decisions, character selection, presentation.
class_name BattleInputWiring
extends RefCounted

static func create_p1_source() -> InputSource:
    return KeyboardInputSource.new(KEY_W, KEY_A, KEY_S, KEY_D, KEY_U, KEY_I, KEY_J, KEY_K, KEY_L)

static func create_p2_source(mode: int) -> InputSource:
    if mode == BattleMode.Mode.VS_CPU:
        return CpuInputSource.new()
    return KeyboardInputSource.new(KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_M, KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_SEMICOLON)
