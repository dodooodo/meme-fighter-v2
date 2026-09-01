# GATE 3 — Telemetry Report

Telemetry is observational only. It consumes already-resolved CombatEvents and read-only post-resolution state. It does not decide damage, hit/block/throw, meter, state transitions, CPU decisions, Snapshot hashes or Replay truth.

## Events

| Event | Representative payload | Emission source | Model |
|---|---|---|---|
| combat.move_start | move/attack instance, fighter/opponent, tick/round | CombatEvent MOVE_STARTED | event-driven |
| combat.hit | raw/scaled/actual damage, HP before/after, hit level, CH, distance/corner, combo | resolved HIT CombatEvent | event-driven |
| combat.block | resolved move/source, distance/corner | resolved BLOCK CombatEvent | event-driven |
| combat.whiff | move/attack instance | move-instance settlement | observer-derived |
| combat.counter_hit | HIT payload | resolved HIT with counter_hit | event-driven |
| combat.punish | HIT payload | defender RECOVERY observation fact | event-driven |
| combat.throw_attempt | throw MoveData identity | MOVE_STARTED + generic throw box | event-driven |
| combat.throw_success | resolved throw payload | resolved THROW CombatEvent | event-driven |
| combat.throw_tech | fighter/move/instance | THROW_TECH CombatEvent | event-driven |
| combat.meter_gain / spend | before/after/delta | read-only Fighter meter diff | state-diff |
| combat.charge_level | charge level + move | MOVE_STARTED resolved against ChargeSpecialData | event-driven |
| combat.ultimate_start / hit / block / whiff | ultimate move provenance | MoveData tag/id + resolved outcome | event/observer |
| combat.status_apply / remove / extend | status id, serial, remaining | read-only status state diff | state-diff |
| combat.mode_enter / exit | mode id, serial, remaining | read-only mode state diff | state-diff |
| combat.resource_change | resource id, before/after/delta | read-only resource diff | state-diff |
| combat.projectile_spawn | projectile id/runtime/owner/source move | read-only ProjectileSystem diff | state-diff |
| combat.projectile_hit | resolved source provenance | HIT/BLOCK CombatEvent source kind | event-driven |
| combat.summon_spawn / hit / destroyed | entity id/runtime/owner/hp/phase | TemporaryEntity state + resolved source | state/event |
| combat.trap_spawn / trigger | area entity id/runtime/owner/state | TemporaryEntity Area diff/resolved source | state/event |
| combat.ko | raw/scaled/actual damage + HP before/after | resolved KO CombatEvent | event-driven |
| combat.corner_state | fighter + corner boolean | read-only position/corner diff | state-diff |

## Character mechanic coverage through generic IDs

- Signal Mark, YA slow, Sticky and Panic Exit are visible through generic status events.
- Super Doge, Dual Blade, True Face and Last Stand are visible through generic mode events.
- Face Actions, Courage and Resolve are visible through generic resource events.
- Penguin/Husky are visible through generic Summon entity events.
- Mage JPEG trap is visible through generic Area/trap events.
- Goblin command grab and OK capture are represented through generic move/throw provenance rather than character-ID telemetry branches.

## Damage provenance

- `raw_damage`: unscaled authored damage transported from the authoritative HitResult.
- `scaled_damage`: authoritative post-proration damage before HP clamping/overkill.
- `actual_hp_damage`: resolved `hp_before - hp_after`.
- KO uses resolved HP before/after supplied by CombatResolver; telemetry does not recalculate combat damage.

## Non-authority / failure isolation

- `BattleSimulation`, Snapshot, Hasher and Replay do not import telemetry transport.
- Replay remains normalized InputFrames.
- State diff is maintained only inside TelemetryMatchAggregator and is never snapshotted/hashed.
- Local sink enqueue/flush failure is reported/contained outside combat. Combat state does not depend on successful telemetry writes.
- Gate 3 tests compare authoritative state signatures with and without observation and cover failing/unconfigured sink behavior.

## Tests authored

- `tests/gate3/test_gate3_telemetry.gd` covers representative Hit, Block, Throw, Throw Tech, KO, meter/resource/status/mode diff, Projectile Hit, Summon Hit/Spawn, Trap Spawn/Trigger, damage provenance and state-hash non-authority.
- Existing `tests/telemetry/test_telemetry_service_integration.gd` retains sink-failure / state-hash equivalence coverage.
