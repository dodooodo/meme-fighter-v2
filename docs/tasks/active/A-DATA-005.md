---
id: A-DATA-005
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, battle/combat/combat_event.gd, battle/combat/combat_resolver.gd, battle/combat/hit_result.gd, battle/battle_scene.gd, tests/telemetry/, tests/run_tests.gd, docs/architecture/, docs/roadmap/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TELEMETRY.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, bash scripts/verify.sh]
---

# Mastery Events

## Goal

Emit sparse, interpretable milestones for successful fighting-game fundamentals.

## Context

Raw input capture is prohibited; mastery must be derived from resolved combat
facts.

## Existing Behavior To Preserve

Combat outcome and player input handling remain unchanged and private.

## Required Change

Emit anti-air, whiff-punish, throw, combo-completion, guard, and ultimate-finish
success events.

## Public/API Contract

Mastery payloads contain stable fighter/move/round facts, not raw input content.

## Implementation Constraints

Events are observational, sparse, and deduplicated by resolved event identity.

## Edge Cases

Single-hit sequences are not combos, simultaneous hits remain distinct, and an
ultimate finish requires an authoritative KO provenance event.

## Test Plan

Change type: feature

Expected test levels: unit, integration, determinism

Pre-change expected failure / characterization: no mastery events exist.

Post-change required checks: focused telemetry and full runtime runners.

## Documentation Impact

Expected: required

Affected docs: telemetry contract.

## Acceptance Criteria

All six roadmap mastery outcomes have test-covered emission rules.

## Rollback / Recovery Notes

Remove external derivation rules; gameplay events remain valid.

## Out of Scope

Achievements, progression rewards, coaching UI, or raw input analysis.
