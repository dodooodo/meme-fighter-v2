---
id: A-MVP-003
stage: A
type: asset
status: in_progress
dependencies: []
allowed_paths: [content/characters/doge/, assets/characters/doge/, presentation/characters/doge_presentation.tres, presentation/visuals/production/, tests/a5/, scripts/static_validate.py, docs/tasks/]
forbidden_paths: [battle/, fighter/, telemetry/, server/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md, docs/production_art_asset_contract.md]
required_checks: [godot --headless --path . -s res://tests/a5/run_a5_tests.gd, python3 scripts/static_validate.py]
---

# Production Presentation

## Goal

Replace Doge's greybox visual with authored production presentation.

## Context

Legacy Doge artwork exists, while v2 currently binds Doge to the generic greybox.

## Existing Behavior To Preserve

Presentation remains a read-only consumer and gameplay boxes remain unchanged.

## Required Change

Provide production base/mode visual scenes, explicit state and move bindings,
and a package portrait.

## Public/API Contract

Stable presentation keys resolve to visible production animations with safe fallbacks.

## Implementation Constraints

Do not use visual dimensions as gameplay geometry.

## Edge Cases

Missing optional art must fall back visibly without changing gameplay.

## Test Plan

Change type: asset

Expected test levels: static, component, visual regression

Pre-change expected failure / characterization: Doge uses greybox_fighter_visual.tscn.

Post-change required checks: focused A5 tests, static validation, manual visual review.

## Documentation Impact

Expected: to-review

Affected docs: A5 manual verification checklist.

## Acceptance Criteria

Doge base and Super Doge presentation load, animate, and remain non-authoritative.

## Rollback / Recovery Notes

Restore the former greybox presentation resource.

## Out of Scope

Golden Pair art changes or an entirely new art pipeline.
