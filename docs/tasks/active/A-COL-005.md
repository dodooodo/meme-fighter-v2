---
id: A-COL-005
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [scripts/, tests/tooling/, assets/presentation/examples/, docs/contributors/, docs/tasks/]
forbidden_paths: [battle/, fighter/, data/, frontend/, presentation/, content/, assets/characters/, server/]
required_specs: [AGENTS.md, presentation/AGENTS.md, docs/architecture/TESTING.md]
required_checks: [python3 -m unittest discover -s tests/tooling, python3 scripts/build_art_manifest.py --manifest assets/presentation/examples/art_build.example.json --validate-only, python3 scripts/static_validate.py]
---

# One-Command Art Build

## Goal

Accept one versioned art build manifest and dispatch existing normalized runtime asset builders.

## Context

Production asset pack types currently use separate scripts and CLI shapes.

## Existing Behavior To Preserve

Existing builders, generated formats, source processing, and presentation-only authority remain unchanged.

## Required Change

Add one fail-closed manifest schema and command that validates every job before running any builder.

## Public/API Contract

The command supports base fighter, mode fighter, projectile/world effect, and ultimate screen jobs, stable unique job IDs, repository-contained paths, deterministic manifest order, and `--validate-only`.

## Implementation Constraints

Reuse existing builder functions. Validation may not create outputs. Reject unknown fields and types.

## Edge Cases

Reject duplicate IDs, unknown types, missing required fields, type-incompatible fields, escaping paths, missing source/spec files, and invalid JSON.

## Test Plan

Change type: tooling

Expected test levels: unit, integration, smoke

Pre-change expected failure / characterization: no aggregate art manifest command exists.

Post-change required checks: schema unit tests, example validate-only smoke, static validation.

## Documentation Impact

Expected: required

Affected docs: contributor commands.

## Acceptance Criteria

One manifest can describe all supported art builds and the command validates the complete batch before producing normalized assets.

## Rollback / Recovery Notes

Remove the wrapper and continue invoking the unchanged individual builders.

## Out of Scope

Changing normalization algorithms or regenerating committed assets.
