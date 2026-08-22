---
id: A-COL-007
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [scripts/, tests/tooling/, docs/contributors/, docs/tasks/]
forbidden_paths: [battle/, fighter/, data/, frontend/, presentation/, content/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/CONTRIBUTOR_CONTRACTS.md, docs/architecture/CHARACTER_PACKAGE.md]
required_checks: [python3 -m unittest discover -s tests/tooling, python3 scripts/simulate_contributor_merges.py, python3 scripts/static_validate.py]
---

# Merge Conflict Simulation

## Goal

Repeatably simulate Art, Balance, Frontend, and Skill branches working on one character and merging without path conflicts.

## Context

The package and domain layout should reduce central-file contention, but the claim needs executable evidence.

## Existing Behavior To Preserve

The real repository, branches, worktrees, and working tree remain untouched by the simulation.

## Required Change

Create an isolated temporary Git repository from representative current files, commit four branches from one base, verify disjoint path ownership, and merge all branches into an integration branch.

## Public/API Contract

The command exits nonzero for missing representative paths, overlapping paths, unexpected changed paths, merge conflicts, or non-clean final state.

## Implementation Constraints

Use temporary storage and local Git only. Do not alter user Git configuration or the real repository.

## Edge Cases

Handle missing Git, command failures, duplicate branch paths, merge conflicts, cleanup, and filenames under the same character scope.

## Test Plan

Change type: tooling

Expected test levels: unit, integration

Pre-change expected failure / characterization: no merge simulation exists.

Post-change required checks: simulation unit tests, live simulation, static validation.

## Documentation Impact

Expected: required

Affected docs: contributor commands.

## Acceptance Criteria

All four independent branches merge cleanly, touch distinct declared files, and the report identifies the target character and per-role paths.

## Rollback / Recovery Notes

Remove the isolated simulation tool and its tests.

## Out of Scope

Guaranteeing all future changes are conflict-free or creating remote branches.
