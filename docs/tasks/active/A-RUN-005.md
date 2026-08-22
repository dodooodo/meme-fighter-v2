---
id: A-RUN-005
stage: A
type: ci
status: done
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
runtime runner aggregates registered suites. The workflow has run successfully
with the pinned Godot runtime, but GitHub branch protection is an external
setting.

## Accepted External Limitation (2026-08-22)

The repository is currently a private repository owned by the personal
`dodooodo` account. GitHub reports that Rulesets cannot be enforced for this
repository until it is moved to a GitHub Team organization account.

The checked-in workflow remains the canonical verification command and must
continue to fail on missing runtime or test failures. However, it is not
currently server-enforced as a required merge gate. The project owner accepted
this external limitation on 2026-08-22 and considers the repository-owned CI
portion complete. Moving to an eligible organization and configuring `Godot
Verify` as a required Ruleset/branch-protection check remains a separately
tracked external follow-up; this status does not claim that enforcement exists.
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
Do not represent the presence of `.github/workflows/godot-verify.yml` as proof
that merges are server-side protected while this repository remains ineligible
for GitHub Rulesets.
## Tests
Workflow syntax/inspection and a CI run after merge/PR.
## Acceptance Criteria
Workflow has pinned runtime and failing verification commands.
## Rollback / Recovery Notes
Revert the workflow independently if the CI environment fails to provision Godot.
After moving to a GitHub Team organization, configure and verify the required
check before changing this task's status.
## Out of Scope
Release/deployment, web export, external branch-protection administration.
