# Responsibility: Complete same-build gameplay snapshot foundation for capture -> restore -> deterministic re-simulation.
# Owns: source frame, typed RoundStateSnapshot, two Fighter snapshots, ProjectileSystem serial and active Projectile snapshots.
# Does NOT own: replay recorder/input source state, networking, presentation/debug events, Nodes, static Resource copies.
class_name BattleStateSnapshot
extends RefCounted

const VERSION: int = 10
var version: int = VERSION
var frame_number: int = 0
var round_state: RoundStateSnapshot = null
var fighter_a: FighterStateSnapshot = null
var fighter_b: FighterStateSnapshot = null
var next_projectile_instance_serial: int = ProjectileSystem.INITIAL_INSTANCE_SERIAL
var projectiles: Array[ProjectileSnapshot] = []

var next_temporary_entity_serial: int = TemporaryEntitySystem.INITIAL_INSTANCE_SERIAL
var temporary_entities: Array[Dictionary] = []
# Gate 2 summon lock/counter state that is group-scoped rather than entity-local.
var temporary_entity_aux_state: Dictionary = {}

# Canonical 7F normal-throw tech windows. Primitive dictionaries only.
var pending_normal_throws: Array[Dictionary] = []
