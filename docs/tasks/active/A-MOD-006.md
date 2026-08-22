---
id: A-MOD-006
stage: A
type: tooling
status: done
dependencies: [A-MOD-005]
allowed_paths: [data/character_validator.gd, data/character_validator.gd.uid, content/, tests/characters/, tests/tooling/, tests/run_tests.gd, scripts/validate_characters.gd, scripts/validate_characters.gd.uid, scripts/validate_characters.sh, scripts/static_validate.py, docs/architecture/, docs/contributors/, docs/stages/, docs/tasks/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/events/, presentation/fighter/, assets/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd, bash scripts/verify.sh]
---
# Task

## Goal

Add a deterministic validator for character packages and their gameplay/presentation references.

## Context

Manifests validate basic identity, but package-wide move, frame, cancel, art-binding, and projectile invariants are not checked centrally.

## Existing Behavior To Preserve

Validation is read-only and must not mutate resources, catalog state, combat state, or generated assets.

## Required Change

Validate unique manifest/character/move/projectile IDs, identity matches, required moves, missing references/art bindings, frame data, cancel targets, and projectile IDs; provide a headless command.

## Public/API Contract

Validation returns stable human-readable errors and exits nonzero from the command when any package is invalid.

## Implementation Constraints

Use typed resources and package manifests; no character-specific branches in generic combat code.

## Edge Cases

Reject null entries, empty arrays, duplicates within/across packages, impossible cancel windows/targets, invalid projectile spawn frames, and missing presentation move bindings.

## Test Plan

Change type: tooling

Expected test levels: static, unit, component, integration

Pre-change expected failure / characterization: invalid fixture packages are not rejected because no validator exists.

Post-change required checks: focused validator tests, valid Golden Pair command run, invalid fixtures, static validation, full runner, global verification, scope validation.

## Documentation Impact

Expected: required

Affected docs: character package validation contract and contributor workflow.

## Acceptance Criteria

Every roadmap validator invariant is covered by focused tests and the Golden Pair passes the headless command.

## Rollback / Recovery Notes

Remove the additive validator and command; manifests remain independently valid.

## Out of Scope

Automatic repair, balance judgment, asset generation, other roster migration.
