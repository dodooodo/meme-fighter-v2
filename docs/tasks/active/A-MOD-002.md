---
id: A-MOD-002
stage: A
type: architecture
status: done
dependencies: [A-MOD-001]
allowed_paths: [data/roster_registry.gd, data/character_catalog.gd, data/character_manifest.gd, data/characters/, presentation/characters/, frontend/, tests/characters/, tests/roster/, tests/run_tests.gd, scripts/static_validate.py, docs/architecture/, docs/tasks/]
forbidden_paths: [battle/, fighter/, presentation/events/, presentation/fighter/, assets/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/CHARACTER_PACKAGE.md]
required_checks: [python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd]
---
# Task
## Goal
Add a CharacterCatalog discovery boundary beside the current hard-coded `RosterRegistry`.
## Context
`data/roster_registry.gd` centrally preloads all 14 roster gameplay/presentation resources and is used by frontend/tests. Generic battle code must remain unaware of concrete IDs.
## Existing Behavior To Preserve
`RosterRegistry.character_by_id`/`presentation_by_id`, all existing resource paths, roster tests, and gameplay behavior remain working until explicit migration tasks change consumers.
## Required Change
Implement documented APIs: `list_manifests()`, `get_manifest(id)`, `load_gameplay(id)`, `load_presentation(id)`, and `register_pack(pack)`. Add only the smallest integration/tests necessary to prove catalog lookup and duplicate/mismatch rejection.
## Public/API Contract
Catalog exposes manifests and immutable resource loading; it must not mutate Fighter/MoveRegistry or be called by generic combat core.
## Implementation Constraints
Use `CharacterManifest` from A-MOD-001; preserve central registry as compatibility adapter; do not move all 14 characters or add character-ID branches to battle/fighter.
## Edge Cases
Unknown IDs, duplicate manifests/pack IDs, gameplay/presentation identity mismatch, and missing references fail predictably.
## Tests
Focused catalog tests wired in `tests/run_tests.gd`; static validation; full runtime runner when Godot is available.
## Acceptance Criteria
The target API is test-covered, existing registry behavior is preserved, and no forbidden gameplay/presentation controller paths change.
## Rollback / Recovery Notes
Keep `RosterRegistry` intact; revert catalog-only additions if the adapter breaks consumers.
## Out of Scope
Golden Pair package move, template, validator CLI, central registry deletion, online/content DLC.
