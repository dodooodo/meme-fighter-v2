# Responsibility: Stable prototype replay format/version constants for same-build deterministic playback.
class_name ReplayFormat
extends RefCounted

const SCHEMA_VERSION: int = 1
const COMBAT_RULES_VERSION: int = 4
const DEFAULT_STAGE_ID: StringName = &"greybox_stage"
const FILE_EXTENSION: String = ".tbf_replay.json"
const VALID_INPUT_MASK: int = (
    InputFrame.InputButton.LIGHT
    | InputFrame.InputButton.HEAVY
    | InputFrame.InputButton.GUARD
    | InputFrame.InputButton.SPECIAL
    | InputFrame.InputButton.ULTIMATE
)
