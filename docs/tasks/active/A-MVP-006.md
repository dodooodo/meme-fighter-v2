---
id: A-MVP-006
stage: A
type: implementation
status: in_progress
dependencies: []
allowed_paths: [fighter/input/, battle/battle_scene.gd, battle/battle_scene.tscn, battle/match/, frontend/, presentation/training/, tests/a5/, tests/run_tests.gd, scripts/static_validate.py, project.godot, docs/tasks/]
forbidden_paths: [telemetry/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TESTING.md]
required_checks: [godot --headless --path . -s res://tests/a5/run_a5_tests.gd, bash scripts/verify.sh]
---

# Training Minimum

## Goal

Expose the roadmap's minimum useful training controls.

## Context

Training match rules exist, but no frontend flow or player-facing controls do.

## Existing Behavior To Preserve

Training remains fixed-tick, replayable, and independent of debug presentation.

## Required Change

Add training launch, reset, standing/crouching dummy guard, frame/box debug
toggle affordances, and canonical input display.

## Public/API Contract

Dummy behavior is an InputSource policy; displays read normalized InputFrames.

## Implementation Constraints

Presentation controls cannot mutate Fighter or BattleSimulation state directly.

## Edge Cases

Reset during charge/projectiles and switching dummy posture without stale edges.

## Test Plan

Change type: feature

Expected test levels: unit, component, integration, smoke, determinism

Pre-change expected failure / characterization: no playable training flow exists.

Post-change required checks: focused A5 and full runtime suites.

## Documentation Impact

Expected: to-review

Affected docs: A5 manual verification checklist.

## Acceptance Criteria

Every listed minimum control works without moving gameplay authority into UI.

## Rollback / Recovery Notes

Remove the training-only input source, overlay, and launch route.

## Out of Scope

Recording/playback slots, frame advantage analyzer, save states, or combo recipes.
