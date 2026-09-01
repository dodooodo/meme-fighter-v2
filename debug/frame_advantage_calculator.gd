# Read-only frame data helper computed from authoritative MoveData; never a second gameplay truth.
class_name FrameAdvantageCalculator
extends RefCounted

static func on_hit(move: MoveData) -> int:
    if move == null: return 0
    return move.hitstun_frames - move.recovery_frames

static func on_block(move: MoveData) -> int:
    if move == null: return 0
    return move.blockstun_frames - move.recovery_frames
