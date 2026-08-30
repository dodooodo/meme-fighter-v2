---
id: A-COL-012
stage: A
type: tooling
status: in_progress
dependencies: []
allowed_paths: [addons/, frontend/, data/content_index.gd, content/validation/, tests/, docs/, project.godot]
forbidden_paths: [battle/, fighter/, presentation/, content/characters/, assets/, scripts/, telemetry/]
required_specs: [AGENTS.md, docs/roadmap/PRODUCTION_ROADMAP.md, docs/stages/active/STAGE_A_EXECUTION.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Land the content tooling work on `main`, where four merged pull requests failed to reach it.
## Context
`A-COL-009`, `A-MVP-008`, `A-COL-010`, and `A-COL-011` were reviewed and merged as a stack, each pull request targeting its parent task branch. GitHub retargets a child pull request onto the parent's base only when the parent is merged *and* its head branch is deleted. Merged back to back with the branches kept, no retarget happened, so each merge landed in its parent branch and `main` received only `A-RUN-007` and `A-COL-008`.

The result: `main` has the content index and its CI gate, but not the editor dock, the movelist screen, the art-pack import, or the binding editor. The work is reviewed, merged, and unreachable.
## Existing Behavior To Preserve
Everything already on `main`, in particular `A-RUN-007`'s Python fix in `scripts/presentation_asset_pipeline/common.py`, which none of the stranded branches contain. `origin/main` is merged into this branch first so that fix survives rather than being reverted.
## Required Change
No new behavior. Merge the four stranded task branches and `origin/main` into one branch and land it, so `main` holds what was already reviewed.
## Public/API Contract
Unchanged. Every API in this branch was contracted by the task packet that introduced it: `A-COL-009`, `A-MVP-008`, `A-COL-010`, `A-COL-011`.
## Implementation Constraints
Integration only: no source change beyond what the four merged pull requests already contained, plus this packet. The merge with `origin/main` must be verified to keep the Python fix, the addon, and the movelist scene.

This packet exists because `validate_task.py` derives one task id from the branch name and validates one packet's `allowed_paths`. A branch spanning four tasks cannot satisfy any single existing packet, and a non-`task/` branch name fails the name rule outright. Rather than merge past a red check, the integration is declared as its own task with `allowed_paths` covering exactly the union of the four.
## Edge Cases
A stranded branch lacking a commit that reached `main` by another route; a merge that silently reverts it; task packets from the four tasks arriving as new files rather than modifications.
## Test Plan
Change type:
- other

Expected test levels:
- static | integration

Pre-change expected failure / characterization:
`main` does not contain `addons/character_content_inspector/plugin.cfg` or `frontend/character_detail_scene.tscn`, so neither the dock nor the movelist screen exists for anyone working from `main`.

Post-change required checks:
`python3 scripts/static_validate.py`, `bash scripts/verify.sh`, run against the merge itself.

## Documentation Impact
Expected:
- none

Affected docs:
Documentation for each merged task travels with it; this packet adds no further documentation change.

## Acceptance Criteria
1. `main` contains the editor dock, the movelist screen, the art-pack import dialog, and the binding writer.
2. `A-RUN-007`'s Python fix is still present after the merge, not reverted.
3. `bash scripts/verify.sh` passes against the merge commit.
4. Task Scope passes, so the pull request lands green rather than being merged past a red check.

## Rollback / Recovery Notes
Revert the merge commit on `main`. Each constituent task remains revertable on its own commits.

## Out of Scope
Any behavior change, any new feature, and the manual verification still owed for the four interfaces, which stay `in progress` in the Stage A tracker until a human has used them.
