---
id: A-DATA-003
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, battle/battle_scene.gd, tests/telemetry/, tests/run_tests.gd, docs/architecture/, docs/roadmap/, docs/stages/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/TELEMETRY.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, bash scripts/verify.sh]
---

# Match Summary

## Goal

Emit one complete summary for every completed or locally interrupted match.

## Context

Stage A needs local match evidence before remote telemetry exists.

## Existing Behavior To Preserve

Round scoring, match winner authority, modes, and scene reset behavior remain
unchanged.

## Required Change

Record participant character IDs, winner, rounds, duration, mode, build/content
versions, disconnect reason, and replay correlation.

## Public/API Contract

`match.completed` is emitted once per match lifecycle and identifies whether the
match ended normally or by reset/scene exit.

## Implementation Constraints

Derive results only from authoritative resolved events and state; telemetry does
not decide when a match ends.

## Edge Cases

Draws, timeouts, training/reset, zero-frame sessions, and duplicate match-end
observation.

## Test Plan

Change type: feature

Expected test levels: unit, integration, smoke

Pre-change expected failure / characterization: no match summary exists.

Post-change required checks: focused telemetry and full runtime runners.

## Documentation Impact

Expected: required

Affected docs: telemetry contract and Stage A execution.

## Acceptance Criteria

One summary contains every required roadmap field using stable values.

## Rollback / Recovery Notes

Remove the scene observer without changing match authority.

## Out of Scope

Match history UI, MMR, server reconciliation, and online disconnect detection.
