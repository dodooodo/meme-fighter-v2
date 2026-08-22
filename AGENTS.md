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

## Before editing

1. Read this file and any nested `AGENTS.md` that applies to the path.
2. Find the task packet; do not begin a task without one, except an explicitly
   approved emergency repair.
3. Read its required specs and inspect the current code, tests, and validators.
4. Confirm its dependencies and allowed/forbidden paths.
5. Plan the smallest change that satisfies its acceptance criteria.

## Required implementation lifecycle

Read rules → read task → read specs → inspect code → dependency check → plan →
smallest implementation → targeted test → global verification → scope audit →
diff review → acceptance check → report.

Do not silently expand task scope. If the task requires an unlisted path or a
new architecture decision, stop and record the escalation in the task/PR report.

## Verification

Run task-required checks and then the project gate:

```bash
python3 scripts/static_validate.py
bash scripts/verify.sh
```

For a scoped task, also run:

```bash
python3 scripts/validate_task.py --task docs/tasks/active/<TASK-ID>.md --base HEAD
```

Runtime is PASS only if Godot actually ran. If the executable is unavailable,
report **NOT EXECUTED**; CI must fail rather than return a false green.

## Scope discipline

Do not perform incidental gameplay refactors, Godot upgrades, rollback, online,
Steam, payment, or UI rewrites. Do not weaken/delete existing assertions to make
a change pass. Preserve working-tree changes that are outside your task.

## Definition of done

A task is done only when its acceptance criteria are met, required checks are
reported truthfully, scope validation passes, documentation is updated where the
task requires it, and the final diff has been reviewed for authority,
determinism, snapshot/replay, telemetry, and scope impact.

## Documentation map

- Combat/current implementation: [ARCHITECTURE.md](ARCHITECTURE.md)
- Character package target: [CHARACTER_PACKAGE.md](docs/architecture/CHARACTER_PACKAGE.md)
- Telemetry contract: [TELEMETRY.md](docs/architecture/TELEMETRY.md)
- Contributor boundaries: [CONTRIBUTOR_CONTRACTS.md](docs/architecture/CONTRIBUTOR_CONTRACTS.md)
- Stage A execution: [STAGE_A_EXECUTION.md](docs/stages/active/STAGE_A_EXECUTION.md)
- Task format: [TASK_TEMPLATE.md](docs/tasks/TASK_TEMPLATE.md)
- Legacy reference inventory: [DORIAN_LEGACY_AUDIT.md](docs/reference/DORIAN_LEGACY_AUDIT.md)

Skills standardize workflow only; they never supersede the specs above.
