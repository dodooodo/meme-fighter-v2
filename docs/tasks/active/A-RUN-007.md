---
id: A-RUN-007
stage: A
type: tooling
status: done
dependencies: []
allowed_paths: [scripts/presentation_asset_pipeline/, docs/]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/, content/, assets/, addons/]
required_specs: [AGENTS.md, docs/contributors/TOOLING.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Let the art pipeline run on the Python a contributor already has, instead of failing with a syntax error on anything older than 3.12.
## Context
`scripts/presentation_asset_pipeline/common.py` writes the SpriteFrames resource using a backslash inside an f-string expression. That only parses from Python 3.12 (PEP 701). Every art builder imports this module, so on macOS's system `python3` (3.9) every build dies with `SyntaxError: f-string expression part cannot include a backslash`, reported against a line that has nothing to do with what the contributor was building. No CI job runs the builders, so nothing catches it: `verify.sh` and both workflows never invoke `build_art_manifest.py`.
## Existing Behavior To Preserve
The generated `.tres` must be byte-identical. Frame ordering, texture ids, durations, loop flags, names, and speeds are unchanged. No builder interface, argument, or output path changes.
## Required Change
Build the frame-entry string before the f-string that embeds it, so the expression contains no backslash.
## Public/API Contract
Unchanged. This is an expression-level rewrite inside `_write_sprite_frames`-adjacent resource emission; no signature, output, or filename changes.
## Implementation Constraints
Output-neutral by construction: the same string is assembled, only earlier. Nothing else in the pipeline requires 3.12, and every module already carries `from __future__ import annotations`, so the union of remaining requirements is Python 3.9 plus Pillow.
## Edge Cases
An animation with a single frame; several animations sharing a texture id sequence; the last animation, which omits the trailing comma.
## Test Plan
Change type:
- bugfix

Expected test levels:
- static | smoke

Pre-change expected failure / characterization:
`python3 scripts/build_art_manifest.py --manifest <mode pack>` fails on Python 3.9 with `SyntaxError: f-string expression part cannot include a backslash` before any output is written.

Post-change required checks:
`python3 scripts/static_validate.py`, `bash scripts/verify.sh`, plus a MODE_FIGHTER build run on both a 3.9 and a 3.12+ interpreter with the outputs compared.

## Documentation Impact
Expected:
- required

Affected docs:
`docs/contributors/TOOLING.md`.

## Acceptance Criteria
1. `scripts/presentation_asset_pipeline/common.py` parses under Python 3.9.
2. A MODE_FIGHTER pack builds successfully under the system `python3`.
3. Building the same spec with the same interpreter and Pillow version before and after the change produces byte-identical output.
4. `bash scripts/verify.sh` passes.

## Rollback / Recovery Notes
Revert the commit. The change is confined to one expression and has no callers to update.

## Out of Scope
Adding a CI job that runs the art builders, declaring the Pillow dependency, and the fact that different Pillow versions re-encode frames to different bytes, which makes builds non-reproducible across Pillow upgrades. Each deserves its own task.
