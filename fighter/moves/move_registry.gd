# Responsibility: Validated runtime lookup of a character's MoveSetData by stable move ID.
# Owns: move-id lookup table and configuration validation errors.
# Does NOT own: current move, move frame, state transitions, HP, input, animation.
# Dependencies: MoveSetData, MoveData.
class_name MoveRegistry
extends RefCounted

var _moves_by_id: Dictionary = {}
var _validation_errors: PackedStringArray = []

func configure(move_set: MoveSetData) -> bool:
    _moves_by_id.clear()
    _validation_errors.clear()
    if move_set == null:
        _validation_errors.append("MoveSetData is null")
        return false

    for index in range(move_set.moves.size()):
        var move: MoveData = move_set.moves[index]
        if move == null:
            _validation_errors.append("MoveSetData contains null MoveData at index %d" % index)
            continue
        if move.id == &"":
            _validation_errors.append("MoveData at index %d has an empty id" % index)
            continue
        if _moves_by_id.has(move.id):
            _validation_errors.append("Duplicate MoveData id: %s" % String(move.id))
            continue
        _moves_by_id[move.id] = move

    for move: MoveData in move_set.moves:
        if move == null or move.charge_special_data == null:
            continue
        var charge := move.charge_special_data
        if not charge.is_valid():
            _validation_errors.append("Invalid ChargeSpecialData on move: %s" % String(move.id))
            continue
        for target_id: StringName in [charge.level_1_move_id, charge.level_2_move_id, charge.level_3_move_id]:
            if not _moves_by_id.has(target_id):
                _validation_errors.append("ChargeSpecialData target missing from MoveSet: %s -> %s" % [String(move.id), String(target_id)])

    return _validation_errors.is_empty()

func has_move(move_id: StringName) -> bool:
    return _moves_by_id.has(move_id)

func get_move(move_id: StringName) -> MoveData:
    if not _moves_by_id.has(move_id):
        return null
    return _moves_by_id[move_id] as MoveData

func validation_errors() -> PackedStringArray:
    return _validation_errors.duplicate()
