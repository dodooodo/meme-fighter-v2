# Resolves a canonical action move ID through active generic mode overrides.
class_name FighterMoveResolver
extends RefCounted

func resolve(canonical_id: StringName, mode: ModeComponent, resources: FighterResourceComponent = null) -> StringName:
    return mode.resolve_move_id(canonical_id, resources) if mode != null else canonical_id
