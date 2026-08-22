---
id: A-COL-003
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [scripts/, tests/tooling/, tests/run_tests.gd, docs/architecture/, docs/contributors/, docs/tasks/]
forbidden_paths: [battle/, fighter/, data/, frontend/, presentation/, content/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [python3 -m unittest discover -s tests/tooling, python3 scripts/static_validate.py, bash scripts/verify.sh]
---

# Balance Table Export

## Goal

Export the formal roster's move balance table as deterministic CSV or Markdown.

## Context

Balance collaborators need reviewable data without editing central registries or manually copying frame data.

## Existing Behavior To Preserve

MoveData resources remain the sole balance authority and are read only.

## Required Change

Add a one-command exporter with character, move, startup, active, recovery, damage, hitstun, blockstun, meter, and range approximation columns.

## Public/API Contract

Rows use stable `CharacterData.id` plus `MoveData.id`; output order and number formatting are deterministic.

## Implementation Constraints

Load actual Godot resources rather than duplicating balance data. Do not write gameplay resources.

## Edge Cases

Fail on missing characters, null move sets, null moves, duplicate stable IDs, invalid output formats, or write errors.

## Test Plan

Change type: tooling

Expected test levels: static, component, integration

Pre-change expected failure / characterization: no balance export command exists.

Post-change required checks: exporter component tests, CSV and Markdown smoke exports, static validation, full Godot runner.

## Documentation Impact

Expected: required

Affected docs: balance workflow and contributor commands.

## Acceptance Criteria

CSV and Markdown exports contain all required columns, stable keys, deterministic ordering, and documented range/meter semantics.

## Rollback / Recovery Notes

Remove exporter scripts, tests, and workflow documentation.

## Out of Scope

Changing balance values or applying spreadsheet edits.
