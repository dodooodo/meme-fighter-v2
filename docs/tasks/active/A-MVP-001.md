---
id: A-MVP-001
stage: A
type: implementation
status: in_progress
dependencies: [A-MOD-007, A-DATA-001]
allowed_paths: [content/characters/, assets/characters/, data/character_catalog.gd, data/character_validator.gd, data/roster_registry.gd, data/characters/doge.tres, data/move_sets/roster/doge_move_set.tres, fighter/input/, battle/battle_scene.gd, battle/battle_scene.tscn, battle/match/, frontend/, presentation/characters/doge_presentation.tres, presentation/data/, presentation/training/, presentation/tutorial/, presentation/visuals/production/, tests/a5/, tests/characters/roster/test_doge.gd, tests/run_tests.gd, scripts/static_validate.py, play.sh, project.godot, docs/architecture/, docs/contributors/, docs/roadmap/, docs/stages/, docs/tasks/]
forbidden_paths: [server/, telemetry/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TESTING.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [./play.sh version, godot --headless --path . -s res://tests/a5/run_a5_tests.gd, godot --headless --path . -s res://tests/a5/run_a5_scene_smoke.gd, bash scripts/test_character.sh doge, python3 scripts/static_validate.py, bash scripts/verify.sh, python3 scripts/validate_task.py --task docs/tasks/active/A-MVP-001.md]
---

# A5 Third Character Aggregate

## Goal

Complete `A-MVP-001` through `A-MVP-007` as one playable Stage A delivery:
package Doge as the mechanic-diverse third fighter, present a three-fighter
selection flow, and add the minimum Training and Tutorial experiences.

## Context

The roadmap defines seven coupled A5 outcomes but no A5 task packets exist. The
user requested all A5 work in one delivery. This packet is the branch and scope
authority for that aggregate; the six sibling packets retain per-outcome
acceptance.

## Existing Behavior To Preserve

The formal 14-character compatibility roster, Golden Pair packages, fixed-tick
simulation, replay determinism, local/CPU modes, debug keys, and telemetry
observation remain valid. Presentation and frontend must not become gameplay
authority.

## Required Change

Migrate Doge to a discoverable Character Package, split every Doge MoveData
resource, bind production presentation, and prove charge behavior remains
deterministic. Preserve the original mode-select layout while sourcing its
three-fighter choices from package name/availability metadata. Add
Training reset, dummy guard, box/frame toggles, input display, and a Tutorial
covering only movement, guard, light/heavy, throw, special, and ultimate.

## Public/API Contract

Built-in playable packages are discovered in sorted package-directory order.
The A5 selectable roster is `magic_orange_cat`, `salad_cat`, and `doge` and is
derived from available manifests, not a new central character switch. Match
launch configuration carries a mode, two package resources, and the appropriate
match rules into BattleScene.

## Implementation Constraints

No generic gameplay branch may inspect `character_id`. Doge's charge, armor,
mode, and move replacement remain typed data. Training dummy behavior produces
canonical InputFrames. Tutorial progress is presentation-only observation and
must not mutate simulation. Legacy Dorian may supply authored art evidence and
assets but not runtime architecture.

## Edge Cases

Handle missing/unavailable manifests, absent portraits, one available fighter,
same-character matches, local and CPU launch, Training reset during active
charge/projectiles, standing and crouching dummy guard, tutorial actions in any
facing direction, and insufficient meter for ultimate.

## Test Plan

Change type:
- feature
- refactor
- asset

Expected test levels:
- static
- unit
- character
- component
- integration
- smoke
- determinism
- e2e
- visual regression

Pre-change expected failure / characterization:
- Doge has no manifest-backed package, embeds all moves in one central move-set,
  uses greybox presentation, and the frontend exposes 14 development entries
  without Training or Tutorial flows.

Post-change required checks:
- Focused A5 runner
- Focused Doge package validator and tests
- Static validation
- Full Godot runtime and determinism suite
- Aggregate task scope validation
- Manual visual/play checklist for final acceptance

## Documentation Impact

Expected:
- required

Affected docs:
- Character Package contract
- Stage A execution status
- production roadmap A5 acceptance
- A5 manual verification checklist

## Acceptance Criteria

- Doge is a valid, catalog-discovered package with external MoveData resources.
- Doge charge thresholds, release moves, interruption/reset, snapshot, replay,
  armor, mode, and replacement move behavior pass regression coverage.
- Doge uses a production visual scene with explicit state/move/mode bindings.
- The original mode-select layout shows exactly three manifest-backed fighter
  choices and launches local or CPU battles without a frontend restyle.
- Training supports reset, standing/crouching dummy guard, frame/box debug, and
  canonical P1/P2 input display.
- Tutorial teaches exactly the seven roadmap subjects and advances only from
  observed input/simulation facts.
- All sibling packet acceptance criteria and required checks pass.

## Rollback / Recovery Notes

Restore Doge's former central gameplay and presentation resources and the
development mode selector, then remove the additive A5 frontend/presentation
services, assets, and tests. Generic combat and Golden Pair packages remain
independently usable.

## Out of Scope

Online play, rollback networking, matchmaking, account systems, remote
telemetry, more than three selectable fighters, advanced training recording,
combo trials, tutorial voiceover, new generic mechanics, or Golden Pair visual
rewrites.
