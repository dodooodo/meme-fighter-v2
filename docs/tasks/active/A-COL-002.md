---
id: A-COL-002
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [.github/PULL_REQUEST_TEMPLATE/, docs/tasks/]
forbidden_paths: [battle/, fighter/, data/, frontend/, presentation/, content/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/CONTRIBUTOR_CONTRACTS.md]
required_checks: [python3 -m unittest discover -s tests/tooling, python3 scripts/static_validate.py]
---

# Role-Based PR Templates

## Goal

Provide Balance, Art, Skill, Frontend, and Backend PR templates.

## Context

Each contributor role has different ownership, evidence, and escalation obligations.

## Existing Behavior To Preserve

Existing CI and pull-request handling remain unchanged.

## Required Change

Add five selectable templates that capture scope, stable IDs, validation evidence, authority boundaries, and manual evidence where relevant.

## Public/API Contract

Template query parameters identify the PR type and templates do not claim tests ran automatically.

## Implementation Constraints

Use GitHub-supported template files and a template chooser; do not invent unavailable reviewers.

## Edge Cases

Every template must make not-executed and not-applicable evidence explicit.

## Test Plan

Change type: tooling

Expected test levels: static, unit

Pre-change expected failure / characterization: no PR templates exist.

Post-change required checks: template structure unit tests and static validation.

## Documentation Impact

Expected: none

Affected docs: none.

## Acceptance Criteria

All five role templates are discoverable and contain role-specific checklists.

## Rollback / Recovery Notes

Remove `.github/PULL_REQUEST_TEMPLATE/`.

## Out of Scope

GitHub organization teams, rulesets, and automatic reviewer assignment.
