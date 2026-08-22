---
id: A-MOD-004
stage: A
type: refactor
status: done
dependencies: [A-MOD-003]
allowed_paths: [content/, data/characters/, data/move_sets/, tests/characters/, tests/roster/, tests/run_tests.gd, scripts/, docs/architecture/, docs/stages/, docs/tasks/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, assets/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd, bash scripts/verify.sh]
---
# Task

## Goal

Split the Golden Pair's inline move-set resources into one MoveData resource per move.

## Context

Each Golden Pair move set currently embeds ten MoveData subresources and their supporting data in one large file.

## Existing Behavior To Preserve

Move IDs, move ordering, frame data, nested mechanics, projectiles, cancels, gameplay hashes, and roster behavior remain unchanged.

## Required Change

Create package `gameplay/moves/` resources and make each package `move_set.tres` reference those MoveData resources only.

## Public/API Contract

MoveSetData continues to expose `moves: Array[MoveData]`; resource layout changes without runtime API changes.

## Implementation Constraints

Split only the Golden Pair; do not rewrite MoveData, MoveRegistry, Fighter, BattleSimulation, or the remaining roster.

## Edge Cases

Nested cancel targets, multi-hit payloads, generic effects, sequences, projectile spawns, and move ordering must survive extraction exactly.

## Test Plan

Change type: refactor

Expected test levels: static, component, integration, determinism

Pre-change expected failure / characterization: record canonical Golden Pair move signatures before extraction.

Post-change required checks: resource layout assertions, signature comparison, roster tests, replay/determinism regression, static validation, full runner, global verification, scope validation.

## Documentation Impact

Expected: required

Affected docs: character package current layout and Stage A execution status.

## Acceptance Criteria

Each Golden Pair move has its own `.tres`; package move sets contain only external MoveData references; behavior signatures and runtime tests pass.

## Rollback / Recovery Notes

Restore the inline move sets and package character references from the prior task commit.

## Out of Scope

Other characters, combat logic changes, balance changes, presentation assets.
