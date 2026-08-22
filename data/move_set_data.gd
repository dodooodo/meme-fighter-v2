# Responsibility: Data-driven list of MoveData resources available to a character.
# Owns: configured MoveData resource references.
# Does NOT own: current move, move frame, fighter state, HP, input, animation, runtime lookup cache.
# Dependencies: MoveData.
class_name MoveSetData
extends Resource

@export var moves: Array[MoveData] = []
