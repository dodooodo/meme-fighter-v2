---
id: A-MVP-007
stage: A
type: implementation
status: in_progress
dependencies: []
allowed_paths: [battle/battle_scene.gd, battle/battle_scene.tscn, battle/match/, frontend/, presentation/tutorial/, tests/a5/, tests/run_tests.gd, scripts/static_validate.py, project.godot, docs/tasks/]
forbidden_paths: [telemetry/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TESTING.md]
required_checks: [godot --headless --path . -s res://tests/a5/run_a5_tests.gd, bash scripts/verify.sh]
---

# Tutorial Minimum

## Goal

Teach only the seven Stage A control fundamentals in a short guided match.

## Context

The current frontend lists controls but has no guided learning flow.

## Existing Behavior To Preserve

Tutorial presentation only observes canonical input and simulation state.

## Required Change

Add ordered lessons for movement, guard, light/heavy, throw, special, and
ultimate with clear prompts and completion feedback.

## Public/API Contract

Lesson definitions are presentation data and completion consumes read-only facts.

## Implementation Constraints

Teach no unlisted mechanics and do not grant authoritative combat outcomes from UI.

## Edge Cases

Facing reversal, early actions, insufficient meter, and tutorial restart.

## Test Plan

Change type: feature

Expected test levels: unit, component, integration, smoke, e2e

Pre-change expected failure / characterization: no tutorial route or lesson model exists.

Post-change required checks: focused A5, global verification, manual flow review.

## Documentation Impact

Expected: to-review

Affected docs: A5 manual verification checklist.

## Acceptance Criteria

The seven lessons progress from observed canonical facts and no additional topic appears.

## Rollback / Recovery Notes

Remove the tutorial-only overlay/model and launch route.

## Out of Scope

Combo trials, character-specific lessons, voiceover, localization framework, or rewards.
