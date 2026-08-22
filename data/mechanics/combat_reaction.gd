# Stable generic combat reaction identifiers shared by data and runtime.
class_name CombatReaction
extends RefCounted

enum Type {
    NONE,
    SLIDE_BACK,
    STAGGER,
    SOFT_KNOCKDOWN,
    HARD_KNOCKDOWN,
    HEAVY_KNOCKDOWN,
    WALL_BOUNCE,
    FORCED_STAND,
}
