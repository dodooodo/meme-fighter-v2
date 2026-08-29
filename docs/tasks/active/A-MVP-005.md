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

Provide a player-facing selector for available packaged fighters, including Niu Lai.

## Context

The original screen is a 14-entry development dropdown. The owner requires its
established layout and selection interaction to remain visually unchanged.

## Existing Behavior To Preserve

Local two-player and deterministic CPU launch remain available.

## Required Change

Keep the original title, P1/P2 dropdowns, local/CPU actions, and control guide.
Limit the dropdowns to the four available manifest-backed fighters and add
Training/Tutorial as a quiet second action row rather than redesigning the page.

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
The first A5 implementation replaced that established layout with fighter cards;
the owner rejected that visual change.

Post-change required checks: focused A5, global verification, manual flow review.

## Documentation Impact

Expected: to-review

Affected docs: A5 manual verification checklist.

## Acceptance Criteria

The original selector layout exposes exactly four available manifest-backed
fighters and can launch both requested versus modes, Training, and Tutorial.

## Rollback / Recovery Notes

Restore the former mode-select scene.

## Out of Scope

Unlock progression, fighters beyond Niu Lai, controller remapping, or online matchmaking.
