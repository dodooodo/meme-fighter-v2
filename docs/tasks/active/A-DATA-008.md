---
id: A-DATA-008
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, battle/battle_scene.gd, tests/telemetry/, tests/run_tests.gd, docs/architecture/, docs/roadmap/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TELEMETRY.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, bash scripts/verify.sh]
---

# Replay Correlation

## Goal

Make each local match summary traceable to its saved replay evidence.

## Context

Replay currently supports deterministic in-memory recording and explicit file
persistence but is not wired into the playable BattleScene lifecycle.

## Existing Behavior To Preserve

Replay schema, normalized input stream, final gameplay hash, and validation stay
unchanged.

## Required Change

Record playable matches, finish them with the authoritative hash, save them under
`user://replays/`, and place stable replay ID/path/save status in the summary.

## Public/API Contract

Telemetry stores correlation metadata only; it never embeds replay frames.

## Implementation Constraints

Replay save failure is reported observationally and does not block match/result
or telemetry summary production.

## Edge Cases

Normal completion, reset/exit, empty recording, save failure, duplicate finalization,
and a summary whose replay could not be persisted.

## Test Plan

Change type: feature

Expected test levels: integration, smoke, determinism

Pre-change expected failure / characterization: BattleScene saves no replay file.

Post-change required checks: focused telemetry and full runtime runners.

## Documentation Impact

Expected: required

Affected docs: telemetry contract and Stage A execution.

## Acceptance Criteria

Every emitted match summary has replay correlation fields and accurately reports
whether its referenced local file was saved.

## Rollback / Recovery Notes

Remove scene replay lifecycle wiring; standalone ReplayRecorder/Codec remain.

## Out of Scope

Replay upload, browser object storage, replay browser UI, and cross-build playback.
