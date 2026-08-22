---
id: A-MOD-001
stage: A
type: architecture
status: done
dependencies: [A-RUN-005]
allowed_paths: [data/, tests/characters/, tests/run_tests.gd, scripts/static_validate.py, docs/architecture/, docs/tasks/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, assets/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/CHARACTER_PACKAGE.md]
required_checks: [python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd]
---
# Task
## Goal
Introduce `CharacterManifest v1` as package metadata without moving the roster.
## Context
Current identity is `CharacterData.id`; current resources are central under `data/` and have no manifest.
## Existing Behavior To Preserve
`CharacterData.id` stays canonical gameplay identity; `RosterRegistry` continues to load current resources.
## Required Change
Add a resource schema with id, display name, version, gameplay/presentation resource, portrait, icon, content pack ID, and availability; add focused schema/identity tests.
## Public/API Contract
Manifest is metadata/discovery only and does not enter snapshot/hash/combat state.
## Implementation Constraints
No mass character migration, catalog, asset pipeline change, or parallel gameplay identity field.
## Edge Cases
Invalid/missing referenced resource and mismatch IDs must be rejected by focused tests/validation.
## Tests
Static validation; wired Godot tests; targeted manifest tests.
## Acceptance Criteria
Schema is documented, test-covered, and has no behavior change to existing roster loading.
## Rollback / Recovery Notes
Remove the additive schema/tests if it proves incompatible before consumers adopt it.
## Out of Scope
Catalog, Golden Pair migration, package directory creation.
