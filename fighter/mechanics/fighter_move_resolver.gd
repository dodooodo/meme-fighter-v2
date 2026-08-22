# Resolves a canonical action move ID through active generic mode overrides.
class_name FighterMoveResolver
extends RefCounted

func resolve(canonical_id: StringName, mode: ModeComponent) -> StringName:
    return mode.resolve_move_id(canonical_id) if mode != null else canonical_id
