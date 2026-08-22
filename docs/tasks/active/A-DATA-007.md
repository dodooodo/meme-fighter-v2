---
id: A-DATA-007
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, tests/telemetry/, tests/run_tests.gd, scripts/static_validate.py, docs/architecture/, docs/roadmap/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/TELEMETRY.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, python3 scripts/static_validate.py]
---

# Local Telemetry Sink

## Goal

Persist valid telemetry as recoverable newline-delimited JSON under
`user://telemetry/`.

## Context

Remote transport is deferred, so Stage A needs a local evidence boundary.

## Existing Behavior To Preserve

Gameplay continues when directories or files cannot be created.

## Required Change

Implement a bounded queue, batched append, deterministic JSONL parsing tests,
drop accounting, and failure containment.

## Public/API Contract

Each non-empty line is one valid Event Envelope v1 object. Sink filenames are
session-scoped and contain no direct player identity.

## Implementation Constraints

No HTTP/database dependency and no file write inside combat authority.

## Edge Cases

Missing directory, invalid event, open/write failure, empty flush, overflow,
and repeated flush.

## Test Plan

Change type: feature

Expected test levels: unit, integration, static

Pre-change expected failure / characterization: telemetry path and sink do not exist.

Post-change required checks: focused telemetry runner and static validation.

## Documentation Impact

Expected: required

Affected docs: telemetry contract.

## Acceptance Criteria

Valid batches append as JSONL, invalid inputs fail closed, and failures never
propagate into simulation.

## Rollback / Recovery Notes

Remove local sink files/classes; user-generated JSONL may be manually deleted.

## Out of Scope

Upload, retry across sessions, encryption, compression, or retention cleanup.
