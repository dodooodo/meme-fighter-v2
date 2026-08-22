# ADR 0005: Local-first telemetry behind the scene/service boundary

- Status: accepted
- Date: 2026-08-23

## Context

Stage A needs match, move, mastery, performance, and replay-correlated evidence,
but v2 previously had only deterministic replay data. The roadmap envelope used
`build_id` and `content_version`, while the architecture draft used
`build_version` and omitted some identity fields. No remote transport exists.

The deterministic combat core cannot wait on file/network work or allow analytics
failure to affect simulation. Existing resolved `CombatEvent` provenance is the
smallest observation surface, although a few pre-apply facts such as defender
airborne/recovery state must be copied before combat application replaces them.

## Decision

Adopt Event Envelope v1 with `event_id`, `installation_id`, `session_id`, optional
`match_id`/`round_id`/`user_id`, `build_id`, `content_version`, `platform`, and a
JSON-safe payload. Use lower-case dotted event names and increment the event
version for incompatible payload changes.

Place telemetry composition in an application autoload and `BattleScene`, outside
`BattleSimulation` and fighter/combat transport authority. Combat result/event
types may carry primitive observational facts but do not import telemetry or
perform persistence. Buffer envelopes and append bounded batches to local JSONL
after simulation ticks. Correlate summaries to separately saved replay files;
never copy replay inputs into telemetry.

Use `build_id` as the canonical field name, retiring the unimplemented
`build_version` draft before downstream consumers exist.

## Consequences

- Local and CPU matches produce analyzable evidence without a backend.
- Sink/replay failures cannot affect deterministic gameplay.
- Remote Stage B transport can consume one established schema.
- The application may lose oldest buffered events under sustained failure; the
  bounded buffer intentionally protects runtime memory.
- Hard-crash delivery, retention enforcement, consent, account deletion, and
  remote data quality remain future work and must not be inferred as complete.

## Alternatives considered

- Emit directly from `BattleSimulation`: rejected because transport lifecycle and
  wall-clock identity would contaminate deterministic authority.
- Write one file event synchronously inside every simulation tick: rejected due
  to blocking risk and excessive volume.
- Wait for a remote analytics backend: rejected because it would delay Stage A
  balance/performance evidence and couple schema design to infrastructure.
