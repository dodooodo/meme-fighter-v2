---
id: A-MOD-003
stage: A
type: architecture
status: in_progress
dependencies: [A-MOD-002]
allowed_paths: [content/, data/characters/, data/roster_registry.gd, presentation/characters/, tests/characters/, tests/roster/, tests/run_tests.gd, scripts/static_validate.py, docs/architecture/, docs/stages/, docs/tasks/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/events/, presentation/fighter/, assets/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd, bash scripts/verify.sh]
---
# Task

## Goal

Migrate only `magic_orange_cat` and `salad_cat` into manifest-backed character packages.

## Context

CharacterManifest and CharacterCatalog are merged, while all roster resources still live in central paths.

## Existing Behavior To Preserve

All 14 roster entries, stable character IDs, gameplay data, presentation bindings, and compatibility lookups continue to work.

## Required Change

Create package roots and manifests for the Golden Pair, move their gameplay and presentation resources, register them through CharacterCatalog, and route their RosterRegistry compatibility entries through package resources without migrating the other 12 characters.

## Public/API Contract

The package manifest is the discovery boundary; CharacterData remains gameplay identity and RosterRegistry remains an additive compatibility adapter.

## Implementation Constraints

Do not migrate all 14 characters, split MoveData yet, move visual assets, or add character-ID branches to generic combat code. The explicit Golden Pair migration may retire only their former central gameplay/presentation resource paths.

## Edge Cases

Both package manifests must load, validate, register atomically, and resolve matching gameplay/presentation identities.

## Test Plan

Change type: feature

Expected test levels: static, component, integration

Pre-change expected failure / characterization: focused Golden Pair package test fails because package manifests do not exist.

Post-change required checks: focused package tests, static validation, full Godot runner, global verification, task scope validation.

## Documentation Impact

Expected: required

Affected docs: character package contract and Stage A execution status.

## Acceptance Criteria

Only the Golden Pair has package manifests; both resolve through CharacterCatalog and compatibility roster behavior remains intact.

## Rollback / Recovery Notes

Move the four migrated resources back to their central paths, remove the two package manifests, and restore the two RosterRegistry entries.

## Out of Scope

Move splitting, package template, validator CLI, per-character command, other roster migrations, visual asset relocation.
