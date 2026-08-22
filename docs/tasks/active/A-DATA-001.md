---
id: A-DATA-001
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, battle/battle_scene.gd, battle/combat/combat_event.gd, battle/combat/combat_resolver.gd, battle/combat/hit_result.gd, tests/telemetry/, tests/run_tests.gd, scripts/static_validate.py, project.godot, docs/adr/, docs/architecture/, docs/roadmap/, docs/stages/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TELEMETRY.md, docs/architecture/TESTING.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, godot --headless --path . -s res://tests/telemetry/run_battle_scene_telemetry_smoke.gd, python3 scripts/static_validate.py, bash scripts/verify.sh, python3 scripts/validate_task.py --task docs/tasks/active/A-DATA-001.md]
---

# A4 Telemetry Foundation Aggregate

## Goal

Complete `A-DATA-001` through `A-DATA-008` as one local-first telemetry
foundation without allowing analytics work to affect deterministic gameplay.

## Context

The roadmap defines eight tightly coupled A4 outcomes but the repository has no
telemetry implementation or task packets. The user requested all A4 work in one
delivery. This packet is the branch and scope authority for that aggregate;
the seven sibling packets retain per-outcome acceptance.

## Existing Behavior To Preserve

`BattleSimulation` remains the only gameplay authority, combat events remain
one-way observations, replay input/hash behavior stays deterministic, and a
telemetry failure never delays or changes a simulation decision.

## Required Change

Add persistent installation identity, session/match/round/event identities, a
versioned event envelope, match/move/mastery/performance event production, a
bounded local JSONL sink, and replay-file correlation. Wire the observer at the
scene/service boundary and preserve presentation delivery of every combat event.

## Public/API Contract

Events use lower-case dotted names and explicit scalar envelope fields. Optional
`user_id` is pseudonymous. Match summaries reference a replay ID and local path;
replay input frames are never copied into telemetry.

## Implementation Constraints

Telemetry transport stays outside fighter/combat authority. Simulation-facing
observation may only copy already-resolved facts. File writes are buffered and
performed after simulation ticks. Buffers are bounded, failures are contained,
and no event is emitted once per simulation frame.

## Edge Cases

Handle first-run identity creation, corrupt identity storage, duplicate combat
events, zero-frame/reset matches, replay-save failure, sink-open failure,
bounded-buffer overflow, missing optional IDs, simultaneous outcomes, timeout,
and local/CPU mode naming.

## Test Plan

Change type:
- feature

Expected test levels:
- static
- unit
- integration
- smoke
- determinism
- performance

Pre-change expected failure / characterization:
- No `telemetry/` implementation or A4 tests exist; BattleScene neither records
  replay files nor emits local match/move/performance telemetry.

Post-change required checks:
- Focused telemetry runner
- Static architecture validation
- Full Godot runtime suite
- Global verification
- Aggregate task scope validation

## Documentation Impact

Expected:
- required

Affected docs:
- telemetry contract
- telemetry ADR
- Stage A execution status
- production roadmap A4 acceptance

## Acceptance Criteria

- Every A4 identity and envelope field is validated and versioned.
- Completed or interrupted local matches produce correlated summary, move, and
  replay artifacts when persistence is available.
- Required mastery and performance event APIs are covered by runtime tests.
- Telemetry remains excluded from snapshot/hash state and sink failures do not
  change simulation results.
- All sibling packet acceptance criteria and required checks pass.

## Rollback / Recovery Notes

Remove the additive telemetry service, tests, scene wiring, and configuration.
Existing combat and replay APIs remain independently usable.

## Out of Scope

Remote ingestion, HTTP, account login, analytics dashboards, consent UI,
retention policy enforcement, online play, and production crash reporting.

## Verification Evidence

Recorded 2026-08-23 against Godot `4.7.2.stable.official.ed1daf0bf`:

- Focused A4 runner: 104 passed, 0 failed.
- Real BattleScene/autoload/replay/local-sink smoke: PASS.
- Static architecture/resource validation: PASS.
- Full `scripts/verify.sh`: PASS, including editor import, runtime regression,
  196 roster pairings, 10,000-frame stress, and replay determinism.
- Task scope validation and diff whitespace validation: PASS.

Manual verification: not required; no visual, feel, hardware, or UX acceptance
criterion is part of A4.
