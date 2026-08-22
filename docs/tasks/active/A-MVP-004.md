---
id: A-MVP-004
stage: A
type: implementation
status: in_progress
dependencies: []
allowed_paths: [content/characters/doge/, tests/a5/, tests/characters/roster/test_doge.gd, tests/m8/, tests/replay/, tests/snapshot/, tests/run_tests.gd, docs/tasks/]
forbidden_paths: [frontend/, telemetry/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TESTING.md]
required_checks: [godot --headless --path . -s res://tests/a5/run_a5_tests.gd, bash scripts/verify.sh]
---

# Charge Regression

## Goal

Prove Doge's package migration preserves the generic charge mechanic.

## Context

Moving and splitting charge resources can break target resolution without a
character-ID branch or obvious parse error.

## Existing Behavior To Preserve

24F/54F thresholds, hold/release, commitment, interruption, reset, snapshot,
hash, replay, heavy cancel, Lv3 armor, and Super Doge mode behavior.

## Required Change

Add Doge-package-focused charge regression coverage.

## Public/API Contract

Charge continues to use typed MoveData and stable move IDs.

## Implementation Constraints

No Doge branch in generic combat code.

## Edge Cases

Test exact threshold boundaries, interrupted charge, restore, and replay.

## Test Plan

Change type: feature

Expected test levels: character, integration, replay, determinism

Pre-change expected failure / characterization: tests load the former central Doge path.

Post-change required checks: focused A5 and full runtime suites.

## Documentation Impact

Expected: none

Affected docs: none.

## Acceptance Criteria

All listed charge cases pass through the packaged Doge data.

## Rollback / Recovery Notes

Remove the focused regression tests with the Doge package rollback.

## Out of Scope

Changing the generic charge contract.
