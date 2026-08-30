---
id: A-COL-010
stage: A
type: tooling
status: in_progress
dependencies: [A-COL-008, A-COL-009]
allowed_paths: [addons/, assets/presentation/, docs/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, data/, content/, scripts/, tests/]
required_specs: [AGENTS.md, docs/contributors/CONTENT_INSPECTOR.md, docs/contributors/TOOLING.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Let an art contributor bring a folder of skill frames into the game from the editor, seeing what will be written before anything is written.
## Context
Importing art today means hand-writing a pack spec JSON and an art manifest JSON, then running `scripts/build_art_manifest.py` from a terminal. That is the third of the three problems this line of work started from: nobody could see what a character had, what an animation looked like, or how to get a skill's image pack in. The first two are solved by `A-COL-008` and `A-COL-009`.
## Existing Behavior To Preserve
Every image rule stays in Python. Crop, pivot, frame ordering, alpha, and output naming are defined by `build_mode_character_assets.py` and are not reimplemented, mirrored, or second-guessed here. `scripts/build_art_manifest.py` remains the only entry point that runs a build, and its validation remains authoritative.
## Required Change
Add an art-pack import dialog behind the dock's existing, currently inert `Import art pack` button. It collects a character, a mode id, and a source folder; derives one animation per subfolder with per-animation fps and loop; writes a MODE_FIGHTER pack spec and a one-job art manifest; runs the manifest validator; and only then offers to run the build, reporting exactly which files the build added, changed, or removed.
## Public/API Contract
No script API. The dialog writes two repository files per import, both intended to be committed: `assets/presentation/specs/<character>_<mode_id>.json` (the pack spec) and `assets/presentation/specs/<character>_<mode_id>.art_manifest.json` (the one-job manifest). It shells out to `python3 scripts/build_art_manifest.py --project-root <root> --manifest <manifest> [--validate-only]`.
## Implementation Constraints
This task introduces the first write path in the addon, so the order is fixed: validate, show, confirm, build, report. The build button stays disabled until validation has passed for the current inputs, and any edit to the inputs invalidates it again. No image is decoded, cropped, or written by GDScript. Source selection uses `res://` access so a path outside the repository cannot be chosen. The dialog never edits gameplay data, presentation bindings, or character packages.
## Edge Cases
A source folder with no subfolders, or a subfolder with no images; a mode id that collides with an existing pack; a source path containing no readable frames; `python3` missing from PATH; a build that fails partway and leaves some outputs written; a validation failure whose message must reach the user unchanged.
## Test Plan
Change type:
- tooling

Expected test levels:
- static | smoke

Pre-change expected failure / characterization:
None applicable. The dialog adds no runtime or gameplay behavior; the builders it calls already have their own validation and are unchanged by this task.

Post-change required checks:
`python3 scripts/static_validate.py`, `bash scripts/verify.sh`. The editor-import step loads the addon, so a script error in the dialog fails verification.

## Documentation Impact
Expected:
- required

Affected docs:
`docs/contributors/CONTENT_INSPECTOR.md`, `docs/contributors/TOOLING.md`, `docs/roadmap/PRODUCTION_ROADMAP.md`.

## Acceptance Criteria
1. The dock's `Import art pack` button opens the dialog instead of being inert.
2. Choosing a source folder lists one animation per subfolder with its frame count, and fps and loop are editable per animation.
3. Validation writes the spec and manifest, runs `build_art_manifest.py --validate-only`, and shows the validator's own output verbatim, including failures.
4. The build button is disabled until validation passes and becomes disabled again whenever an input changes.
5. Running the build reports the files added, changed, and removed under the character's asset directory.
6. A completed build refreshes the dock index so the new animations appear without restarting the editor.
7. Only MODE_FIGHTER packs are offered. `base_fighter`, `effect`, and `ultimate_screen` remain CLI-only and the dialog says so rather than pretending otherwise.
8. An interpreter that cannot run the builders is reported as such before anything is written, naming the version found and the version needed, rather than surfacing as whatever the builders happen to fail with.
9. MANUAL, OUTSTANDING: a human opens the dialog, browses to a real pack, and confirms the form, the animation table, and the log read clearly at the dock's width. Headless probes drove every code path but nobody has looked at this dialog.

## Rollback / Recovery Notes
Revert the branch. Generated specs and built assets are ordinary tracked files; `git checkout` restores them. Disabling the plugin also removes the dialog.

## Out of Scope
Importing `base_fighter`, `effect`, or `ultimate_screen` packs; editing presentation bindings so a new animation becomes reachable from a move; grid and strip sheet sources, which the spec format supports but which need their own UI; and rebuilding an existing pack in place from the dialog.
