---
id: A-CHAR-001
stage: A
type: asset
status: in_progress
dependencies: [A-MOD-007]
allowed_paths: [ARCHITECTURE.md, assets/characters/niu_lai/, content/characters/niu_lai/, data/roster_registry.gd, docs/architecture/CHARACTER_PACKAGE.md, docs/production_art_asset_contract.md, docs/stages/active/STAGE_A_EXECUTION.md, docs/tasks/active/A-CHAR-001.md, docs/tasks/active/A-MVP-005.md, presentation/data/, presentation/fighter/fighter_presentation_resolver.gd, presentation/visuals/production/, scripts/build_split_character_assets.py, scripts/split_embedded_move_set.py, tests/a5/, tests/characters/roster/test_niu_lai.gd, tests/presentation/test_character_presentation_data.gd]
forbidden_paths: [battle/, fighter/, telemetry/, server/]
required_specs: [AGENTS.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md, docs/production_art_asset_contract.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/test_character.sh niu_lai, bash scripts/verify.sh]
---

# Add Niu Lai Production Character

## Goal

Make Niu Lai selectable with the recovered production action frames and the
existing deterministic Courage gameplay.

## Context

Niu Lai already has central gameplay data and a focused roster regression, but
uses greybox presentation and is absent from manifest-backed Character Select.
The recovered source contains 112 transparent frames grouped by authored action;
the source `ROUND_1` and `ROUND_2` folders are organizational only.

## Existing Behavior To Preserve

Courage 0–3, charge thresholds, move IDs, combat values, snapshots, replay, and
the generic no-character-branch gameplay architecture remain unchanged.

## Required Change

Package Niu Lai's gameplay and moves, import every recovered source frame,
compose runtime animations, bind Courage-dependent presentation variants, and
expose the package through Character Select and the compatibility roster.

## Public/API Contract

Presentation bindings may conditionally select an animation from a read-only
fighter resource value. They never mutate gameplay or add character-ID logic.

## Implementation Constraints

Source image dimensions and pivots are presentation-only. Recovered action
ordering must be explicit and deterministic. All gameplay moves remain
package-owned external resources.

## Edge Cases

Missing resource values use the unconditional visual binding. Overlapping
conditional ranges are invalid. Missing optional animation art falls back using
the shared production visual adapter.

## Test Plan

Change type: feature, asset, tooling

Expected test levels: static, unit, component, integration, smoke, determinism

Pre-change expected failure / characterization: `test_character.sh niu_lai`
rejects the unknown package and Niu Lai resolves to greybox presentation.

Post-change required checks: focused character validation, static validation,
global verification, and manual in-battle visual/feel review.

## Documentation Impact

Expected: required

Affected docs: character package state, production art input contract, Stage A
available roster, and Character Select acceptance count.

## Acceptance Criteria

Niu Lai appears as the fourth available package, loads all 112 recovered source
frames through production presentation, uses Courage-appropriate state and move
art, and preserves deterministic gameplay behavior.

## Rollback / Recovery Notes

Remove the package manifest to withdraw Niu Lai from discovery; the former
central gameplay and placeholder presentation remain available for recovery.

## Out of Scope

New Courage gameplay rules, combat balance changes, online play, or other roster
characters.
