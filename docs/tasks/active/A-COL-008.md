---
id: A-COL-008
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [data/content_index.gd, data/content_index.gd.uid, data/character_validator.gd, content/validation/, scripts/content_report.gd, scripts/content_report.gd.uid, scripts/content_report.sh, scripts/verify.sh, tests/, docs/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, content/characters/, assets/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Make a character package's gameplay, presentation, and built art legible in one place, and fail CI when a move binds an animation that cannot play.
## Context
Move data, presentation bindings, and the built SpriteFrames live in three unrelated files and are never joined. Nothing verifies that a bound `animation_key` exists in the SpriteFrames, and nothing requires a move to have a binding at all. `CharacterPresentationData.animation_for_move` falls back to `PresentationAnimationIds.ATTACK_FALLBACK`, and no character package builds an `attack` animation, so an unbound move renders nothing while every existing check stays green. `MoveData.animation_id` is written in every move resource but is read by no runtime code, which makes the existing `animation_id != &""` check misleading.
## Existing Behavior To Preserve
`CharacterValidator.validate_manifest` keeps its current per-manifest checks and error strings. Presentation resolution, fallback constants, and all gameplay data stay unchanged. Validation stays read-only and instantiates no scene.
## Required Change
Add `ContentIndex`, a read-only join over manifest, move set, presentation bindings, mode bindings, and the SpriteFrames reached through the packed scene state. Surface error-severity findings through `CharacterValidator.validate_manifests` and render the full index as a markdown report from `scripts/content_report.gd`, wired into `scripts/verify.sh`. Known unbound moves are declared in `content/validation/unbound_moves_allowlist.json`.
## Public/API Contract
`ContentIndex.build(manifests, allowlisted_unbound)` populates `characters`; `ContentIndex.issues(minimum_severity)` returns issue dictionaries with `severity`, `code`, `character_id`, and `message`. `CharacterValidator.load_unbound_allowlist(path)` is static and returns `character_id -> Array[StringName]`.
## Implementation Constraints
Presentation-only: no gameplay, snapshot, hash, or replay surface changes. Read SpriteFrames via `PackedScene.get_state()` so nothing is instantiated. Errors block CI; warnings never do. One shared index feeds the validator, the report, and the editor dock so they cannot disagree.
## Edge Cases
Missing presentation resource; missing or stale build manifest JSON; a mode pack that covers only part of the base animation set; conditioned bindings with no unconditional fallback that leave a resource value uncovered; an absent allowlist file.
## Test Plan
Change type:
- tooling

Expected test levels:
- static | unit

Pre-change expected failure / characterization:
A new unit test binding a move to a non-existent animation key passes validation before the change and fails after it.

Post-change required checks:
`python3 scripts/static_validate.py`, `bash scripts/verify.sh`.

## Documentation Impact
Expected:
- required

Affected docs:
`docs/contributors/TOOLING.md`, `docs/contributors/CONTENT_INSPECTOR.md`, `docs/roadmap/PRODUCTION_ROADMAP.md`.

## Acceptance Criteria
1. A binding whose `animation_key` is absent from the character SpriteFrames fails `validate_characters`.
2. A move with no presentation binding fails validation unless listed in the allowlist.
3. A conditioned binding group with no unconditional fallback that leaves a resource value uncovered fails validation. NOT VERIFIABLE on this base: `MovePresentationBinding` and `StatePresentationBinding` gain `resource_id` / `resource_min_value` / `resource_max_value` with `task/A-CHAR-001-niu-lai-production-assets`, which has not merged. The index reads those fields through `Object.get` so it works on both schemas, and the two variant tests skip until the fields exist. Re-run them after A-CHAR-001 merges.
4. Orphaned built animations and partial mode packs are reported as warnings and never fail CI.
5. `scripts/content_report.sh` renders one markdown table per character covering moves, states, bindings, frame data, and issues.
6. `bash scripts/verify.sh` runs the report and passes on the current `main` content.

## Rollback / Recovery Notes
Revert the branch. `ContentIndex` is additive; removing the `_append_content_index_errors` call restores prior validation behavior.

## Out of Scope
The editor dock (`addons/character_content_inspector`), any GUI art import, any write path to `.tres` or `.json` content, and producing the missing charge-level animations for the Golden Pair.
