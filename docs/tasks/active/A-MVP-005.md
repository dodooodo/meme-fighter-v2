---
id: A-MVP-005
stage: A
type: implementation
status: in_progress
dependencies: [A-MOD-007]
allowed_paths: [content/characters/, assets/characters/, data/character_catalog.gd, frontend/, battle/battle_scene.gd, battle/match/, tests/a5/, tests/run_tests.gd, scripts/static_validate.py, project.godot, docs/tasks/]
forbidden_paths: [telemetry/, server/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md]
required_checks: [godot --headless --path . -s res://tests/a5/run_a5_tests.gd, bash scripts/verify.sh]
---

# Character Select v1

## Goal

Provide a player-facing selector for the three Stage A fighters.

## Context

The current screen is a 14-entry development dropdown.

## Existing Behavior To Preserve

Local two-player and deterministic CPU launch remain available.

## Required Change

Show exactly three cards with portrait, name, availability, P1/P2 choice, and
local/CPU start actions derived from manifests.

## Public/API Contract

Selectable characters come from available package manifests.

## Implementation Constraints

Do not add a new central registry or leak selection into combat authority.

## Edge Cases

Unavailable/missing portraits, same-character selection, and keyboard focus.

## Test Plan

Change type: feature

Expected test levels: component, integration, smoke, e2e, visual regression

Pre-change expected failure / characterization: frontend has dropdowns and 14 entries.

Post-change required checks: focused A5, global verification, manual flow review.

## Documentation Impact

Expected: to-review

Affected docs: A5 manual verification checklist.

## Acceptance Criteria

Exactly three available fighters can launch both requested versus modes.

## Rollback / Recovery Notes

Restore the former mode-select scene.

## Out of Scope

Unlock progression, more fighters, controller remapping, or online matchmaking.
