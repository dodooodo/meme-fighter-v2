---
id: A-RUN-003
stage: A
type: tooling
status: done
dependencies: [A-RUN-001]
allowed_paths: [scripts/verify.sh, scripts/, README.md, docs/, .github/workflows/godot-verify.yml]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/]
required_specs: [AGENTS.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [bash -n scripts/verify.sh, python3 scripts/static_validate.py]
---
# Task
## Goal
Make one documented runtime contract for editor import, runtime tests, and static validation.
## Context
Commands exist in README and verify script but need CI-aligned ordering and reporting.
## Existing Behavior To Preserve
`tests/run_tests.gd` remains the runtime test entry point.
## Required Change
Standardize `godot --headless --path . --editor --quit`, `godot --headless --path . -s res://tests/run_tests.gd`, and `python3 scripts/static_validate.py`.
## Public/API Contract
The same commands execute locally and in CI.
## Implementation Constraints
No alternate test framework or duplicate verification pipeline.
## Edge Cases
Runtime absence must fail gate per A-RUN-002.
## Tests
Static validation, shell syntax, actual Godot run when available.
## Acceptance Criteria
One command contract is referenced by script, docs, and CI.
## Completion Evidence
PR #6 passed Task Scope and Godot Verify on 2026-08-22. CI ran the shared
`bash scripts/verify.sh` contract under the pinned Godot 4.7.2 stable binary.
## Rollback / Recovery Notes
Restore prior command documentation only if the Godot runner contract changes.
## Out of Scope
New tests or major test refactors.
