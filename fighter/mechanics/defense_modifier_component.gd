class_name DefenseModifierComponent
extends RefCounted

var _modifiers: Array[DefenseModifierData] = []

func configure(mechanics: CharacterMechanicsData) -> void:
    _modifiers = mechanics.defense_modifiers.duplicate() if mechanics != null else []

func block_pushback_permille(source_move: MoveData) -> int:
    if source_move == null:
        return 1000
    var result := 1000
    for modifier: DefenseModifierData in _modifiers:
        if modifier == null:
            continue
        var applies := modifier.source_tags.is_empty()
        for tag: StringName in modifier.source_tags:
            if source_move.tags.has(tag):
                applies = true
                break
        if applies:
            result = (result * modifier.block_pushback_permille) / 1000
    return result
