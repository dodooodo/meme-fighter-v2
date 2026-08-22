---
id: A-COL-004
stage: A
type: architecture
status: done
dependencies: [A-COL-003]
allowed_paths: [docs/architecture/, docs/contributors/, docs/tasks/, scripts/, tests/tooling/]
forbidden_paths: [battle/, fighter/, data/, frontend/, presentation/, content/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/CONTRIBUTOR_CONTRACTS.md]
required_checks: [python3 -m unittest discover -s tests/tooling, python3 scripts/static_validate.py]
---

# Balance Import Strategy

## Goal

Define the validation-first contract required before spreadsheet data may modify authoritative resources.

## Context

Raw `.tres` overwrite is unsafe because references, stable identity, and non-balance fields share resource files.

## Existing Behavior To Preserve

The A3 balance command is export-only; authored resources remain authoritative.

## Required Change

Specify stable IDs, versioned schema validation, duplicate/range checks, source fingerprints, a mandatory diff preview, explicit apply, atomic writes, and post-apply validation.

## Public/API Contract

No balance import may write unless preview and validation succeed against the same source revision.

## Implementation Constraints

Document unsupported behavior honestly. Do not add a partial writer or direct raw overwrite path.

## Edge Cases

Cover stale exports, missing/extra rows, duplicate IDs, locale-formatted numbers, schema drift, edits to derived columns, and concurrent source changes.

## Test Plan

Change type: docs

Expected test levels: static

Pre-change expected failure / characterization: no canonical round-trip safety contract exists.

Post-change required checks: documentation contract assertions and static validation.

## Documentation Impact

Expected: required

Affected docs: balance workflow and contributor contracts.

## Acceptance Criteria

The strategy requires stable IDs, schema validation, diff preview, and forbids raw overwrite without validation; export-only current status is explicit.

## Rollback / Recovery Notes

Revert the strategy document before implementing any importer under a replacement approved contract.

## Out of Scope

Spreadsheet service integration and resource mutation.
