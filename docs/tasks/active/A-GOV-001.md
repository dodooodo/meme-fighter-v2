---
id: A-GOV-001
stage: A
type: governance
status: in_progress
dependencies: []
allowed_paths: [AGENTS.md, .agents/skills/, .github/workflows/, scripts/static_validate.py, scripts/validate_task.py, battle/combat/collision_system.gd, fighter/combat/hitbox_owner.gd, fighter/mechanics/defense_modifier_component.gd, tests/, docs/]
forbidden_paths: [data/, battle/battle_simulation.gd, fighter/fighter.gd, presentation/, frontend/, assets/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh, python3 scripts/validate_task.py --task docs/tasks/active/A-GOV-001.md]
---

# Task

## Goal

Close the engineering-system enforcement loop before Stage A feature work.

## Context

Bootstrap CI provisions Godot successfully but stops on five pre-existing static
validator drifts. Task scope validation defaults to `HEAD`, validates dependency
existence only, and is not a PR check. `main` has no branch protection.

## Existing Behavior To Preserve

Preserve gameplay behavior, fixed-tick authority, current 5000-HP tuning,
multi-hit duplicate-contact protection, canonical hashing, and the no-fake-runtime rule.

## Required Change

- Align stale static assertions with the current implementation contracts.
- Compare committed task changes against PR base/merge-base.
- Require completed dependency status for ready/in-progress/done packets.
- Add a separate PR Task Scope check using `task/<ID>-<slug>` branches.
- Replace linear documentation priority with authority by domain.
- Configure required main-branch PR/check/force-push protection externally.

## Public/API Contract

`validate_task.py --task <packet>` resolves an automatic merge-base locally;
CI passes the exact PR base SHA. Task branches must match
`task/<TASK-ID>-<slug>` and the packet frontmatter ID must equal the filename ID.

## Implementation Constraints

Do not suppress a runtime/static assertion merely to get green. Validator changes
must assert the current stronger implementation. Keep repository health and PR
scope validation as separate CI jobs.

## Edge Cases

Fail closed for shallow/missing merge-base, unknown task IDs, missing specs,
unfinished dependencies, forbidden paths, and zero resolved PR changes.

## Tests

Add standard-library unit tests for parser, dependency, ID, and diff semantics.
Run static validation, local task validation, global verification, and PR CI.

## Acceptance Criteria

Static validation is green; PR CI reaches and passes actual Godot tests; Task
Scope rejects committed out-of-scope changes; required checks protect `main`.

## Rollback / Recovery Notes

Revert workflow/protection independently if GitHub check names must migrate;
never restore false-green validation behavior.

## Out of Scope

CharacterManifest/Catalog, gameplay features, balance changes, Steam, online,
monetization, release/deployment, and unrelated P2 governance automation.
