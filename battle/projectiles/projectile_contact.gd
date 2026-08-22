# Responsibility: Immutable-style geometry/provenance facts for one detached projectile overlap candidate.
# Owns: owner/defender IDs, source move/spawn/projectile runtime identity, hit position, projectile-origin incoming side.
# Does NOT own: HIT/BLOCK classification, HP/meter mutation, MoveRunner connection facts, presentation.
# Dependencies: StrikeContact provenance base only.
class_name ProjectileContact
extends StrikeContact

var projectile_instance_id: int = 0
var spawn_index: int = -1
var projectile_id: StringName = &""
