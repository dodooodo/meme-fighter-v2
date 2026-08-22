# Dorian / Meme Fighter v2 — Agent Instructions

## Project

`meme-fighter-v2` is the canonical production repository. It is a Godot 4.x
2D fighting game. Current programme stage: **Stage A — Gameplay / Collaboration
Foundation**. Read the active task packet before making a task-scoped change.

## Non-negotiable architecture

- `BattleSimulation` is gameplay authority; it advances at fixed 60 Hz.
- Presentation may observe gameplay but must not decide or mutate it.
- Every future-affecting gameplay field must be snapshot, restore, and hash state.
- Generic core must not branch on `character_id`; character differences are data-driven.
- Platform SDKs, HTTP, and telemetry must not enter the combat core.
- Telemetry is asynchronous/observational and must never block simulation.
- Core changes require replay and determinism regression coverage.

The detailed, current combat contract is [ARCHITECTURE.md](ARCHITECTURE.md).

## Repository model and truth hierarchy

This repository is authoritative. `../Dorian` is legacy, read-only reference:
inspect it for evidence, never copy its architecture by default and never modify it.

When sources conflict, use this order:

1. Existing v2 production invariants and tests
2. [Production roadmap](docs/roadmap/PRODUCTION_ROADMAP.md)
3. [Platform strategy](docs/roadmap/PLATFORM_STRATEGY.md)
4. Architecture specs in `docs/architecture/`
5. Task packet in `docs/tasks/active/`
6. Legacy audit/reference material

## Git and workspace preflight

Before editing repository files, read applicable root/nested rules and the task
packet, then inspect current branch, working tree, worktrees, and HEAD. When a
remote is available, fetch it and compare the branch with the intended base
(normally `origin/main`). `start-task` standardizes this preflight.

- Never implement normal task work directly on `main`.
- One Task Packet normally maps to one branch: `task/<TASK-ID>-<slug>`; runtime
  repairs may use `fix/<TASK-ID>-<slug>` when that is clearer.
- Do not discard existing working-tree changes to start another task.
- Use a separate worktree **and** task branch if this checkout has unrelated
  changes, belongs to another active task, is in use by another worker, or tasks
  are concurrent. Reuse an existing task branch/worktree when one already exists.
- Never use `git reset --hard`, `git clean -fd`/`-fdx`, or `git stash` to handle
  unrelated work without explicit authorization. Do not overwrite or delete
  another worker's untracked work.

## Required implementation lifecycle

Read rules → read task → read specs → preflight Git/workspace → select/create
branch or worktree → inspect code → dependency check → test plan → RED or
characterization baseline when applicable → smallest implementation → GREEN →
refactor → targeted tests → integration/smoke/regression as required → global
verification → task scope audit → documentation impact review → final diff
review → commit → clean-tree check → push/prepare PR → CI → review → merge.

`start-task`, `implement-task`, `verify-change`, and `prepare-pr` implement the
workflow; they do not supersede task packets or architecture specs. Do not
silently expand scope. Escalate any unlisted path or new architecture decision.

## Test-first and verification

Behavior-changing work is test-first by default. For new behavior, make an
acceptance test RED, implement the minimum, make it GREEN, then refactor. For a
bug, first add and reproduce a regression. For a refactor, first ensure enough
regression/characterization coverage. Choose evidence by change risk and
acceptance criterion; do not create meaningless tests merely to claim TDD.
Non-behavioral changes use suitable parser/schema, script, syntax, lint, smoke,
integration, or documented manual evidence instead. The canonical taxonomy and
selection rules are [TESTING.md](docs/architecture/TESTING.md).

Run task-required checks and then the project gate:

```bash
python3 scripts/static_validate.py
bash scripts/verify.sh
```

For a scoped task, also run:

```bash
python3 scripts/validate_task.py --task docs/tasks/active/<TASK-ID>.md --base <task-base>
```

Runtime is PASS only if Godot actually ran. Unavailable runtime is **NOT
EXECUTED**, never PASS. Any behavior/code-affecting edit after final verification
invalidates it: rerun the relevant checks for the final diff before committing.

## Documentation, commits, and PRs

Every task performs a documentation impact review. Update docs when a contract,
schema, architecture, documented behavior, workflow, CLI, invariant, task/stage
status, or existing documentation changes. Otherwise state `Docs impact: none`;
do not create README churn.

Before committing, inspect `git status --short`, `git diff --check`, and the
final `git diff`; confirm task scope, acceptance, verification, docs impact, and
absence of unrelated/debug files. Include the Task ID in the commit subject,
for example `A-MOD-002: add manifest-backed character catalog`. Afterwards the
tree should be clean (or a recorded exception) and the committed diff must be
the verified final diff.

Normal completed tasks use a PR: push the task branch and open/prepare it when
a writable remote exists unless the task is explicitly local-only or the user
opts out. Never push directly to `main`, force-push `main`, bypass protection,
merge without authorization, merge red required CI, or call a PR ready while
required checks fail. PR summaries use committed diff and actual results only.

## Scope discipline and definition of done

Do not perform incidental gameplay refactors, Godot upgrades, rollback, online,
Steam, payment, or UI rewrites. Do not weaken/delete existing assertions to make
a change pass. Preserve working-tree changes outside your task.

A task is done only when acceptance criteria are met, required checks are
truthfully reported, scope validation passes, docs impact is reviewed, and the
final diff is reviewed for authority, determinism, snapshot/replay, telemetry,
and scope impact.

## Documentation map

- Combat/current implementation: [ARCHITECTURE.md](ARCHITECTURE.md)
- Testing strategy: [TESTING.md](docs/architecture/TESTING.md)
- Character package target: [CHARACTER_PACKAGE.md](docs/architecture/CHARACTER_PACKAGE.md)
- Telemetry contract: [TELEMETRY.md](docs/architecture/TELEMETRY.md)
- Contributor boundaries: [CONTRIBUTOR_CONTRACTS.md](docs/architecture/CONTRIBUTOR_CONTRACTS.md)
- Stage A execution: [STAGE_A_EXECUTION.md](docs/stages/active/STAGE_A_EXECUTION.md)
- Task format: [TASK_TEMPLATE.md](docs/tasks/TASK_TEMPLATE.md)
- Legacy reference inventory: [DORIAN_LEGACY_AUDIT.md](docs/reference/DORIAN_LEGACY_AUDIT.md)
