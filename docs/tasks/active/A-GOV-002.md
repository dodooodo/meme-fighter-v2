---
id: A-GOV-002
stage: A
type: tooling
status: blocked
dependencies: []
allowed_paths: [AGENTS.md, CLAUDE.md, .agents/skills/, docs/architecture/, docs/tasks/, scripts/, .github/, CONTRIBUTING.md]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/, assets/]
required_specs: [AGENTS.md, docs/architecture/CONTRIBUTOR_CONTRACTS.md]
required_checks: [python3 scripts/validate_task.py --task docs/tasks/active/A-GOV-002.md --base main, python3 scripts/static_validate.py, bash scripts/verify.sh]
---

# Task

## Goal

Upgrade the repository engineering lifecycle to task-scoped, branch-isolated,
worktree-safe, TDD-first, verification-gated, documentation-aware, and PR-driven
development.

## Existing Behavior To Preserve

Existing architecture/task contracts, global verification commands, task scope
validator, and the Godot verification workflow remain authoritative.

## Required Change

Extend canonical policy, testing strategy, workflow skills, and task template
without creating a parallel architecture or changing gameplay.

## Test Plan

Change type: tooling

Expected test levels: static

Pre-change expected failure / characterization: inspect current policies and run
task parsing/scope checks against the lifecycle diff.

Post-change required checks: task parser/scope validation, Python syntax checks
for changed scripts if any, static validation, and global verification.

## Documentation Impact

Expected: required

Affected docs: `AGENTS.md`, `docs/architecture/TESTING.md`, task template, and
workflow skills.

## Acceptance Criteria

The repository policy and skills provide the requested lifecycle, use one
canonical testing strategy, preserve unrelated work, and report verification
truthfully.

## Blocker

The existing global static gate has five failures outside this task's allowed
paths. They must be repaired by scoped follow-up work before this task's PR can
be considered green or merged.

## Out of Scope

Gameplay, character/catalog work, battle refactors, asset/presentation changes,
Steam, networking, payments, and telemetry implementation.
