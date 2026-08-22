---
id: A-RUN-006
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [play.sh, docs/tasks/]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/, assets/]
required_specs: [AGENTS.md, docs/tasks/TASK_TEMPLATE.md]
required_checks: [./play.sh version, ./play.sh test, python3 scripts/validate_task.py --task docs/tasks/active/A-RUN-006.md]
---
# Task

## Goal

Provide one repository-root command for launching the game, opening the Godot
editor, and running the complete local runtime test suite.

## Context

The pinned Godot 4.7.2 app is stored once in the workspace-level
`.godot_runtime/` directory and is shared by all worktrees.

## Existing Behavior To Preserve

The existing Godot project entry point and `tests/run_tests.gd` remain
authoritative.

## Required Change

Add an executable `play.sh` that discovers the shared runtime (with PATH
fallbacks) and exposes `play`, `editor`, `test`, and `version` commands.

## Public/API Contract

`./play.sh` launches the game; `./play.sh editor` opens the editor;
`./play.sh test` imports and runs the complete headless suite.

## Implementation Constraints

Do not copy or commit the Godot application into the repository. Resolve the
project root relative to the script so every checkout/worktree behaves alike.

## Edge Cases

Missing Godot fails with an actionable path and non-zero exit status. Installed
`godot` or `godot4` remains a supported fallback.

## Test Plan

Change type:
- tooling

Expected test levels:
- static | smoke | integration

Pre-change expected failure / characterization:
- Users must type an absolute Godot binary path or manually configure PATH.

Post-change required checks:
- `./play.sh version`
- `./play.sh test`
- `python3 scripts/validate_task.py --task docs/tasks/active/A-RUN-006.md`

## Documentation Impact

Expected:
- required

Affected docs:
- `play.sh`

## Acceptance Criteria

- The launcher uses the shared pinned Godot 4.7.2 runtime.
- Game, editor, tests, and version commands are available.
- The full runtime suite passes through the launcher.

## Rollback / Recovery Notes

Remove `play.sh` if replaced by an equivalent cross-platform launcher.

## Out of Scope

Bundling Godot, changing game behavior, and changing the test runner.
