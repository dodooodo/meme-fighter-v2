---
id: A-COL-001
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [.github/, scripts/, tests/tooling/, tests/run_tests.gd, docs/architecture/, docs/contributors/, docs/stages/, docs/tasks/, assets/presentation/examples/]
forbidden_paths: [battle/, fighter/, data/, frontend/, presentation/, content/, server/, assets/characters/]
required_specs: [AGENTS.md, docs/architecture/CONTRIBUTOR_CONTRACTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 -m unittest discover -s tests/tooling, python3 scripts/static_validate.py, python3 scripts/simulate_contributor_merges.py, bash scripts/verify.sh]
---

# A3 Contributor Tooling Aggregate

## Goal

Complete `A-COL-001` through `A-COL-007` as one explicitly authorized A3 delivery while preserving gameplay and presentation authority boundaries.

## Context

The roadmap defines the seven A3 outcomes but did not yet include task packets. The user requested all A3 work in one delivery. This packet is the branch and scope authority for that aggregate delivery; the six sibling packets retain per-outcome acceptance.

## Existing Behavior To Preserve

The current Godot project, character resources, presentation assets, deterministic simulation, runtime verification, and existing asset builders remain unchanged.

## Required Change

Add domain-separated CODEOWNERS, five role PR templates, deterministic balance export, a validation-first balance import strategy, a manifest-driven art build entrypoint, a mechanic authoring guide, and a repeatable four-branch merge-conflict simulation.

## Public/API Contract

Contributor commands and document contracts must use stable character/move IDs, fail closed on invalid input, and never mutate gameplay resources as an unvalidated raw overwrite.

## Implementation Constraints

Do not alter gameplay, frontend, presentation runtime, character packages, or normalized production assets. Reuse existing asset builders. Tool output must be deterministic and tool failures must return nonzero.

## Edge Cases

Reject malformed art manifests, duplicate job IDs, unknown job types, paths outside the repository, missing inputs, duplicate balance keys, schema drift, and overlapping simulated branch paths.

## Test Plan

Change type: tooling

Expected test levels: static, unit, integration, smoke

Pre-change expected failure / characterization: A3 files, role templates, aggregate tools, and repeatable simulation commands do not exist.

Post-change required checks: tooling unit tests, static validation, art-manifest validation smoke, balance export smoke when Godot is available, merge simulation, full Godot runner, global verification, and task scope validation.

## Documentation Impact

Expected: required

Affected docs: contributor contracts, balance workflow, mechanic authoring, Stage A execution, and contributor command guide.

## Acceptance Criteria

Every A3 roadmap outcome has an executable or inspectable artifact, invalid inputs fail closed, all declared checks pass or are truthfully reported as not executed, and the final diff remains within this packet.

## Rollback / Recovery Notes

Remove the A3-only templates, scripts, tests, examples, and documentation. No runtime resource migration is required.

## Out of Scope

Balance value changes, gameplay schemas, combat runtime components, actual art regeneration, server implementation, organization/team creation, and branch-protection administration.
