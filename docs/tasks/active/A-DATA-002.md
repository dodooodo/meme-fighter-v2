---
id: A-DATA-002
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, tests/telemetry/, tests/run_tests.gd, scripts/static_validate.py, project.godot, docs/adr/, docs/architecture/, docs/roadmap/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/TELEMETRY.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, python3 scripts/static_validate.py]
---

# Event Envelope v1

## Goal

Define and validate one versioned, JSON-safe envelope for every telemetry event.

## Context

The roadmap and telemetry contract use inconsistent build-field names and event
examples. A4 must resolve them before data is persisted or sent remotely.

## Existing Behavior To Preserve

No gameplay or replay schema changes.

## Required Change

Implement the documented v1 envelope with unique event identity, UTC occurrence
time, installation/session context, optional match/round/user context,
build/content/platform dimensions, and a dictionary payload.

## Public/API Contract

Event names are lower-case dotted domains. Incompatible payload changes increment
`event_version`; envelope keys and value types are explicit and JSON-safe.

## Implementation Constraints

Do not serialize Objects, Resources, input frames, direct account identifiers,
or secrets.

## Edge Cases

Reject empty required IDs, malformed event names, unsupported versions,
non-dictionary payloads, and non-JSON-safe values.

## Test Plan

Change type: feature

Expected test levels: unit, static

Pre-change expected failure / characterization: no envelope builder exists.

Post-change required checks: focused telemetry runner and static validation.

## Documentation Impact

Expected: required

Affected docs: telemetry contract and ADR.

## Acceptance Criteria

Valid events round-trip through JSON and invalid envelopes fail closed.

## Rollback / Recovery Notes

Remove the additive envelope implementation before any remote consumer exists.

## Out of Scope

Schema registry service, backend ingestion, or migrations beyond v1.
