---
id: A-RUN-001
stage: A
type: tooling
status: ready
dependencies: []
allowed_paths: [README.md, project.godot, .github/workflows/godot-verify.yml, docs/]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/]
required_specs: [AGENTS.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Pin Godot 4.7.2 consistently for local documentation and CI.
## Context
README says 4.7.2 was used and the foundational workflow pins it, but there is
not yet runtime evidence that the local/CI pin is operational.
## Existing Behavior To Preserve
Do not upgrade Godot or alter gameplay/resources.
## Required Change
Declare 4.7.2 as the supported runtime in CI and developer-facing docs.
## Public/API Contract
`godot --version` in CI must report the pinned release.
## Implementation Constraints
Use an auditable pinned download/action; do not accept a dev/RC version.
## Edge Cases
Document any platform-specific binary invocation without changing simulation.
## Tests
Run static validation and CI YAML syntax/inspection; runtime requires Godot.
## Acceptance Criteria
Docs and CI name exactly 4.7.2; no gameplay paths change.
## Rollback / Recovery Notes
Revert tooling/docs only if the pinned binary is unavailable.
## Out of Scope
Godot upgrade, export preset work, game changes.
