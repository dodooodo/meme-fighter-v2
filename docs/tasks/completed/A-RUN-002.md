---
id: A-RUN-002
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [scripts/verify.sh, tests/, README.md, docs/]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/]
required_specs: [AGENTS.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [bash -n scripts/verify.sh, bash scripts/verify.sh]
---
# Task
## Goal
Prevent `verify.sh` from returning success when no Godot executable exists.
## Context
The current script prints `NOT RUN` then exits 0, creating a false green.
## Existing Behavior To Preserve
Static validation still runs before runtime invocation; available `godot` and `godot4` remain supported.
## Required Change
Return non-zero when neither executable is available; retain an explicit diagnostic.
## Public/API Contract
`bash scripts/verify.sh` is the global verification gate, not a source-only success proxy.
## Implementation Constraints
Do not hide runtime failures, install dependencies, or change test content.
## Edge Cases
Use `godot4` only if `godot` is absent.
## Tests
Shell syntax; execute once in an environment without Godot and expect non-zero.
## Acceptance Criteria
Missing runtime is a failing gate and a truthful message; static result remains visible.
## Completion Evidence
Implemented by this foundational setup: `scripts/verify.sh` now exits 2 when
neither `godot` nor `godot4` is available. Runtime has not been executed here;
the present project static gate has pre-existing failures that stop verification
before that branch can be reached.
## Rollback / Recovery Notes
Revert only this script behavior if a separate source-only command is formally introduced.
## Out of Scope
Pinning CI, executing runtime tests, gameplay work.
