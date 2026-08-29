---
id: A-MVP-008
stage: A
type: implementation
status: in_progress
dependencies: []
allowed_paths: [frontend/, tests/, docs/]
forbidden_paths: [battle/, fighter/, data/, presentation/, content/, assets/, scripts/, addons/]
required_specs: [AGENTS.md, frontend/AGENTS.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Let a player open a character and watch each of its moves play, so choosing a fighter is informed by what the moves look like rather than by their names.
## Context
Character select is two `OptionButton`s and a start button: a player cannot see what any character does before committing to a match. Every fighting game answers this with a movelist screen. The same screen is the natural home for contributor-facing data, so one page serves players, balance, and art at different levels of disclosure rather than three tools diverging.
## Existing Behavior To Preserve
The P1/P2 selector layout, the VS CPU / 2P Local / Training / Tutorial entry points, and the battle start path are unchanged. `A-MVP-005` fixes the selector layout, so the detail page is reached by an added button rather than by restructuring the screen.
## Required Change
Add `CharacterDetailModel`, resolving each move's animation through the same runtime path the battle uses, and a detail scene listing the character's moves with frame data and an animation preview rendered by the character's own `fighter_visual_scene`. Add a `MOVE LIST` entry point to the mode select screen.
## Public/API Contract
`CharacterDetailModel.configure(manifest) -> bool`, `display_name()`, `move_count()`, and `move_row(index) -> Dictionary` with keys `move_id`, `display_name`, `animation_key`, `playback_key`, `has_animation`, `startup_frames`, `active_frames`, `recovery_frames`, `total_frames`, `damage`, `hit_level`.
## Implementation Constraints
Frontend reads catalog and presentation resources only; it must not touch `BattleSimulation` or define combat rules. The page resolves animations through `CharacterPresentationData.animation_for_move`, the same call `FighterPresentationResolver` makes, so it shows what the game will really play including fallbacks. `ContentIndex` is tooling and must not be referenced from a runtime scene; the page derives "no animation bound" from `animation_for_move(id, &"")` returning empty. Only the selected character's package is loaded.
## Edge Cases
A move with no presentation binding; a manifest with no presentation resource or no visual scene; a character whose animation is missing from `SpriteFrames` and reaches `ProductionFighterVisual`'s generic fallback; an empty roster; switching characters while a preview is playing.
## Test Plan
Change type:
- feature

Expected test levels:
- static | unit

Pre-change expected failure / characterization:
`CharacterDetailModel` does not exist, so a test asserting that the Golden Pair's moves resolve to animations, and that `salad_wave_l1` reports no bound animation, fails to load.

Post-change required checks:
`python3 scripts/static_validate.py`, `bash scripts/verify.sh`.

## Documentation Impact
Expected:
- required

Affected docs:
`docs/roadmap/PRODUCTION_ROADMAP.md`.

## Acceptance Criteria
1. `CharacterDetailModel` lists every move in a character's move set with its resolved animation key and frame data.
2. A move with no presentation binding reports `has_animation == false` while still offering a `playback_key`, so the page can label it instead of silently showing the fallback as if it were correct.
3. The detail scene previews the selected move using the character's own `fighter_visual_scene` in preview mode.
4. The mode select screen reaches the detail page without changing the P1/P2 selector layout or any existing entry point.
5. Switching character or move stops the previous preview before starting the next.
6. The preview loops continuously. Attack animations are authored non-looping because a match drives their frames from the move timeline, so the screen replays them on `animation_finished` rather than editing the `SpriteFrames` the game shares.
7. `bash scripts/verify.sh` passes.
8. MANUAL, OUTSTANDING: a human opens the screen and confirms the preview is framed and scaled sensibly, the movelist is readable, and the flow back to mode select behaves. Headless probes cover data and node wiring only; nobody has looked at this screen.

## Rollback / Recovery Notes
Revert the branch. The model and scene are additive; removing the `MOVE LIST` button restores the previous mode select screen exactly.

## Out of Scope
Input-command notation for moves, combo or cancel-route display, move descriptions or lore copy, visual design polish, and the contributor diagnostics layer that would surface `ContentIndex` findings in game.
