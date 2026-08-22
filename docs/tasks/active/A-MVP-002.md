---
id: A-MVP-002
stage: A
type: implementation
status: in_progress
dependencies: [A-MOD-007]
allowed_paths: [content/characters/doge/, data/characters/doge.tres, data/move_sets/roster/doge_move_set.tres, tests/a5/, tests/characters/roster/test_doge.gd, scripts/static_validate.py, docs/architecture/, docs/tasks/]
forbidden_paths: [battle/, fighter/, frontend/, telemetry/, server/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [godot --headless --path . -s res://tests/a5/run_a5_tests.gd, bash scripts/test_character.sh doge, python3 scripts/static_validate.py]
---

# Split Doge Moves

## Goal

Make every Doge move an independently authored package resource.

## Context

Doge's eleven moves are embedded in one central move-set resource.

## Existing Behavior To Preserve

Stable move IDs, frame data, boxes, charge thresholds, armor, mode effects,
cancel behavior, and balance values remain unchanged.

## Required Change

Create one package-owned `.tres` per move and a move set containing only
external MoveData references.

## Public/API Contract

MoveRegistry sees the same stable IDs and data after loading the package.

## Implementation Constraints

Do not introduce character-specific runtime code or silently rebalance Doge.

## Edge Cases

All charge targets and the mode replacement move must resolve after splitting.

## Test Plan

Change type: refactor

Expected test levels: static, character, integration, determinism

Pre-change expected failure / characterization: Doge's move set embeds MoveData.

Post-change required checks: focused A5 tests, Doge package validation, global verification.

## Documentation Impact

Expected: required

Affected docs: Character Package contract.

## Acceptance Criteria

No Doge MoveData is embedded and all prior Doge behavior passes unchanged.

## Rollback / Recovery Notes

Restore the former central embedded move set.

## Out of Scope

Balance changes or move redesign.
