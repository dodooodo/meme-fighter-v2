---
id: A-GOV-003
stage: A
type: governance
status: done
dependencies: []
allowed_paths: [AGENTS.md, docs/tasks/]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/, assets/]
required_specs: [AGENTS.md, docs/tasks/TASK_TEMPLATE.md]
required_checks: [python3 scripts/validate_task.py --task docs/tasks/active/A-GOV-003.md]
---
# Task

## Goal

Prevent incomplete automated or manual evidence from being reported as full
task completion anywhere in the project.

## Context

Some tasks combine implementation, Godot runtime checks, and human play or
visual/feel review. These evidence classes are not interchangeable.

## Existing Behavior To Preserve

The existing fail-closed runtime and task acceptance rules remain authoritative.

## Required Change

Require all agents to report implementation, automated verification, and manual
verification separately and prohibit `done` while required evidence is missing.

## Public/API Contract

None.

## Implementation Constraints

This is a repository-wide governance rule, not a rule owned by one feature task.

## Edge Cases

Unavailable runtime is `NOT EXECUTED`; headless success cannot certify feel;
source inspection cannot certify runtime or manual behavior.

## Test Plan

Change type:
- docs

Expected test levels:
- static

Pre-change expected failure / characterization:
- The runtime rule exists, but the three evidence classes and human-review
  completion boundary are not stated explicitly.

Post-change required checks:
- `python3 scripts/validate_task.py --task docs/tasks/active/A-GOV-003.md`
- `git diff --check`

## Documentation Impact

Expected:
- required

Affected docs:
- `AGENTS.md`

## Acceptance Criteria

- Root agent instructions define the three evidence statuses.
- Tasks requiring human judgment cannot be called complete before human review.
- Missing runtime cannot be called PASS or full completion.

## Rollback / Recovery Notes

Revert this governance wording only if replaced by an equivalent or stricter
repository-wide completion-evidence rule.

## Out of Scope

Changing any feature implementation or retroactively rewriting task history.
