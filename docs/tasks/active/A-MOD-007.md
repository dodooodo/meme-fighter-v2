---
id: A-MOD-007
stage: A
type: tooling
status: done
dependencies: [A-MOD-006]
allowed_paths: [data/character_catalog.gd.uid, data/character_manifest.gd.uid, tests/characters/, tests/tooling/, scripts/test_character.gd, scripts/test_character.gd.uid, scripts/test_character.sh, scripts/validate_characters.sh, scripts/static_validate.py, docs/architecture/, docs/contributors/, docs/stages/, docs/tasks/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, assets/, content/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [bash -n scripts/test_character.sh, python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd, bash scripts/verify.sh]
---
# Task

## Goal

Provide `./scripts/test_character.sh <character_id>` for focused package validation and character tests.

## Context

The global runner is comprehensive but slow and does not give contributors a single-character feedback loop.

## Existing Behavior To Preserve

The global test runner and verification command remain authoritative and unchanged in scope.

## Required Change

Resolve a package by stable ID, validate it, run the matching focused character suite, and fail predictably for unknown or invalid IDs.

## Public/API Contract

The command accepts exactly one character ID and exits nonzero on usage, lookup, validation, or test failure.

## Implementation Constraints

Do not duplicate gameplay rules in shell; route resource and test behavior through Godot scripts.

## Edge Cases

Missing argument, extra argument, unknown character, template directory, validation failure, and character-test failure must return nonzero.

## Test Plan

Change type: tooling

Expected test levels: static, component, integration

Pre-change expected failure / characterization: command invocation fails because the script does not exist.

Post-change required checks: shell syntax, success for both Golden Pair IDs, failure for unknown ID/invalid arity, static validation, full runner, global verification, scope validation.

## Documentation Impact

Expected: required

Affected docs: per-character contributor workflow and A2 status.

## Acceptance Criteria

The documented command gives deterministic focused results for each packaged character and reliable failures for invalid input.

## Rollback / Recovery Notes

Remove the additive wrapper and focused runner; global verification remains available.

## Out of Scope

Testing non-packaged roster characters, editor UI, CI matrix expansion.
