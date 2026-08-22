---
id: A-MOD-005
stage: A
type: tooling
status: done
dependencies: [A-MOD-004]
allowed_paths: [content/, tests/tooling/, scripts/static_validate.py, docs/architecture/, docs/contributors/, docs/stages/, docs/tasks/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, assets/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd, bash scripts/verify.sh]
---
# Task

## Goal

Provide a reusable `content/characters/_template/` package scaffold.

## Context

The Golden Pair establishes the first concrete package layout, but contributors need a safe copyable starting point.

## Existing Behavior To Preserve

The template is inert and must not register as a playable character or alter runtime behavior.

## Required Change

Add documented manifest, gameplay, moves, presentation, and asset placeholders that can be copied without combat-core edits.

## Public/API Contract

New characters fill package resources and register a manifest; they do not modify generic combat code.

## Implementation Constraints

Template resources must be excluded from runtime discovery/validation as playable content until copied and filled.

## Edge Cases

Static validation must distinguish the reserved `_template` directory from actual packages.

## Test Plan

Change type: tooling

Expected test levels: static, schema

Pre-change expected failure / characterization: template structure check fails because the directory is absent.

Post-change required checks: template structure test, static validation, full runner, global verification, scope validation.

## Documentation Impact

Expected: required

Affected docs: character authoring workflow.

## Acceptance Criteria

The scaffold is complete, inert, documented, and requires no battle/fighter edits to copy into a new package.

## Rollback / Recovery Notes

Remove the inert template directory and its documentation.

## Out of Scope

Code generation, editor plugins, migrating another roster character.
