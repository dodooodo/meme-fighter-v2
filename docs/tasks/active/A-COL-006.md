---
id: A-COL-006
stage: A
type: docs
status: done
dependencies: []
allowed_paths: [docs/architecture/, docs/contributors/, docs/tasks/, tests/tooling/]
forbidden_paths: [battle/, fighter/, data/, frontend/, presentation/, content/, assets/, server/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/CONTRIBUTOR_CONTRACTS.md]
required_checks: [python3 -m unittest discover -s tests/tooling, python3 scripts/static_validate.py]
---

# Mechanic Authoring Guide

## Goal

Give skill contributors a concrete data-first decision guide for mechanics.

## Context

The project already has generic mechanic data and runtime seams but lacks one contributor-facing authoring path.

## Existing Behavior To Preserve

Combat authority, generic core, stable IDs, snapshot/restore/hash, replay, and presentation boundaries remain canonical.

## Required Change

Document when to use MoveData, GameplayEffectData, CharacterMechanicsData, or a new runtime component, plus escalation and snapshot/hash checklists.

## Public/API Contract

New character differences must be data-driven; any future-affecting runtime state must be captured, restored, hashed, and replay-tested.

## Implementation Constraints

The guide may explain current contracts but may not introduce a new architecture decision.

## Edge Cases

Cover one-shot effects versus persistent configuration, cross-character genericity, presentation-only behavior, identity, determinism, and rollback failures.

## Test Plan

Change type: docs

Expected test levels: static

Pre-change expected failure / characterization: no complete mechanic authoring guide exists.

Post-change required checks: required-section assertions and static validation.

## Documentation Impact

Expected: required

Affected docs: mechanic authoring guide and contributor contracts.

## Acceptance Criteria

Every roadmap topic is explicit and the guide includes a usable snapshot/hash/replay checklist.

## Rollback / Recovery Notes

Remove the guide and its link from contributor documentation.

## Out of Scope

Adding mechanics, data types, runtime components, or gameplay tests.
