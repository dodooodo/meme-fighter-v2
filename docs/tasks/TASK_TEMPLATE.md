---
id: TASK-ID
stage: A
type: implementation
status: draft
dependencies: []
allowed_paths: []
forbidden_paths: []
required_specs: []
required_checks: []
---

# Task

## Goal

## Context

## Existing Behavior To Preserve

## Required Change

## Public/API Contract

## Implementation Constraints

## Edge Cases

## Tests

## Acceptance Criteria

## Rollback / Recovery Notes

## Out of Scope

Frontmatter uses a deliberately restricted YAML subset: scalars and bracketed
string lists only. It is parsed by `scripts/validate_task.py`; keep every path
repository-relative and use no YAML anchors, multiline values, or nested maps.
Valid statuses: `draft`, `blocked`, `ready`, `in_progress`, `done`.

Task branches use `task/<TASK-ID>-<lowercase-slug>`. Pull-request scope is
validated against the PR base SHA. A packet cannot be `ready`, `in_progress`,
or `done` until every packet in `dependencies` has status `done`.
