# Primitive-only authoritative runtime for non-projectile temporary combat entities.
class_name TemporaryEntityRuntime
extends RefCounted

enum Kind { AREA, SUMMON, HAZARD, SEQUENCE }

var kind: Kind = Kind.AREA
var instance_id: int = 0
var owner_fighter_id: int = 0
var data_id: StringName = &""
var position_units: Vector2i = Vector2i.ZERO
var facing: int = 1
var remaining_lifetime_frames: int = 0
var age_frames: int = 0
var hp: int = 0
var phase: int = 0
var phase_remaining: int = 0
var target_fighter_id: int = 0
var triggered: bool = false
var force_triggered: bool = false
var sequence_step_mask: int = 0
var recorded_positions: Dictionary = {}
var contacted_fighter_ids: Array[int] = []
var attack_serial: int = 0
var activation_delay_remaining: int = 0
var pending_remove: bool = false

func capture_primitive() -> Dictionary:
    var recorded: Dictionary = {}
    var keys: Array = recorded_positions.keys()
    keys.sort()
    for key in keys:
        var p: Vector2i = recorded_positions[key]
        recorded[str(key)] = [p.x, p.y]
    return {
        "kind": int(kind), "instance_id": instance_id, "owner_fighter_id": owner_fighter_id,
        "data_id": String(data_id), "position": [position_units.x, position_units.y], "facing": facing,
        "remaining": remaining_lifetime_frames, "age": age_frames, "hp": hp, "phase": phase,
        "phase_remaining": phase_remaining, "target_fighter_id": target_fighter_id,
        "triggered": triggered, "force_triggered": force_triggered, "sequence_step_mask": sequence_step_mask,
        "recorded_positions": recorded, "contacted_fighter_ids": contacted_fighter_ids.duplicate(),
        "attack_serial": attack_serial, "activation_delay_remaining": activation_delay_remaining, "pending_remove": pending_remove,
    }

func restore_primitive(value: Dictionary) -> void:
    kind = int(value.get("kind", Kind.AREA))
    instance_id = int(value.get("instance_id", 0))
    owner_fighter_id = int(value.get("owner_fighter_id", 0))
    data_id = StringName(str(value.get("data_id", "")))
    var pos: Array = value.get("position", [0, 0])
    position_units = Vector2i(int(pos[0]), int(pos[1]))
    facing = -1 if int(value.get("facing", 1)) < 0 else 1
    remaining_lifetime_frames = int(value.get("remaining", 0))
    age_frames = int(value.get("age", 0))
    hp = int(value.get("hp", 0))
    phase = int(value.get("phase", 0))
    phase_remaining = int(value.get("phase_remaining", 0))
    target_fighter_id = int(value.get("target_fighter_id", 0))
    triggered = bool(value.get("triggered", false))
    force_triggered = bool(value.get("force_triggered", false))
    sequence_step_mask = int(value.get("sequence_step_mask", 0))
    recorded_positions.clear()
    var rec: Dictionary = value.get("recorded_positions", {})
    var keys: Array = rec.keys(); keys.sort()
    for key in keys:
        var pair: Array = rec[key]
        recorded_positions[int(key)] = Vector2i(int(pair[0]), int(pair[1]))
    contacted_fighter_ids.clear()
    for item in value.get("contacted_fighter_ids", []): contacted_fighter_ids.append(int(item))
    attack_serial = int(value.get("attack_serial", 0))
    activation_delay_remaining = maxi(0, int(value.get("activation_delay_remaining", 0)))
    pending_remove = bool(value.get("pending_remove", false))
