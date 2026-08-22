---
id: A-DATA-004
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, battle/combat/combat_event.gd, battle/combat/combat_resolver.gd, battle/combat/hit_result.gd, battle/battle_scene.gd, tests/telemetry/, tests/run_tests.gd, docs/architecture/, docs/roadmap/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TELEMETRY.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, bash scripts/verify.sh]
---

# Move Telemetry

## Goal

Produce bounded per-match move summaries suitable for balance analysis.

## Context

Combat already emits stable move and attack-instance provenance but no analytics
aggregation exists.

## Existing Behavior To Preserve

Move resolution, hit/block/throw results, presentation event delivery, snapshots,
and replay hashes remain identical.

## Required Change

Aggregate use, hit, block, whiff, punish, counter-hit, damage, distance buckets,
and corner-state counts by fighter and move.

## Public/API Contract

`move.summary` is aggregate/action telemetry, never per-frame polling.

## Implementation Constraints

Only copy observational facts into combat events where post-resolution state
would otherwise destroy the fact. Do not add telemetry dependencies to combat.

## Edge Cases

Multi-hit moves, projectiles resolving after their source move, cancels, trades,
throws, duplicate event delivery, and unresolved move instances at match end.

## Test Plan

Change type: feature

Expected test levels: unit, integration, determinism

Pre-change expected failure / characterization: move events are not aggregated.

Post-change required checks: focused telemetry, replay/determinism, and full runtime runners.

## Documentation Impact

Expected: required

Affected docs: telemetry contract.

## Acceptance Criteria

All required metrics are emitted with deterministic aggregation and no gameplay
state/hash impact.

## Rollback / Recovery Notes

Remove observational fields and the external aggregator.

## Out of Scope

Balance dashboards, frame-input capture, and server-side cohorts.
