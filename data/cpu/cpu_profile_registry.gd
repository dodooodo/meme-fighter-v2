# Read-only resource registry for data-driven CPU profiles/difficulties.
class_name CpuProfileRegistry
extends RefCounted

const PROFILE_ROOT := "res://data/cpu/profiles/"
const DIFFICULTY_ROOT := "res://data/cpu/difficulties/"

static func profile_for(character_id: StringName) -> CpuUtilityProfile:
    var path := "%s%s.tres" % [PROFILE_ROOT, String(character_id)]
    return load(path) as CpuUtilityProfile if ResourceLoader.exists(path) else null

static func difficulty_for(id: StringName) -> CpuDifficultyData:
    var path := "%s%s.tres" % [DIFFICULTY_ROOT, String(id)]
    return load(path) as CpuDifficultyData if ResourceLoader.exists(path) else null
