---
id: A-RUN-005
stage: A
type: ci
status: ready
dependencies: [A-RUN-001, A-RUN-002, A-RUN-003, A-RUN-004]
allowed_paths: [.github/workflows/, scripts/, README.md, docs/]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/]
required_specs: [AGENTS.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [bash -n scripts/verify.sh, python3 scripts/static_validate.py]
---
# Task
## Goal
Require static, runtime, character, replay, and stress coverage in pull-request CI.
## Context
The foundational setup supplies `.github/workflows/godot-verify.yml`; its
runtime runner aggregates registered suites, but it has not run yet and GitHub
branch protection is an external setting.
## Existing Behavior To Preserve
Existing static validator and `tests/run_tests.gd` remain the verification authority.
## Required Change
Validate the supplied pinned workflow in CI and configure its successful check
as required through repository branch protection.
## Public/API Contract
The required check fails on missing runtime or any invoked test failure.
## Implementation Constraints
Do not use a second test runner or claim GitHub branch protection is configured in repository files.
## Edge Cases
Branch-protection configuration is an external repository setting; document it as a follow-up.
## Tests
Workflow syntax/inspection and a CI run after merge/PR.
## Acceptance Criteria
Workflow has pinned runtime and failing verification commands.
## Rollback / Recovery Notes
Revert the workflow independently if the CI environment fails to provision Godot.
## Out of Scope
Release/deployment, web export, external branch-protection administration.
