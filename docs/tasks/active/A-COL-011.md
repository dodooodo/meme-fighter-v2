---
id: A-COL-011
stage: A
type: tooling
status: in_progress
dependencies: [A-COL-008, A-COL-009]
allowed_paths: [addons/, tests/, docs/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, data/, content/, assets/, scripts/]
required_specs: [AGENTS.md, docs/contributors/CONTENT_INSPECTOR.md, docs/architecture/CONTRIBUTOR_CONTRACTS.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Let a contributor bind a move to an animation from the dock, choosing from the animations that actually exist, without hand-editing a `.tres`.
## Context
Binding a move today means opening `character_presentation.tres` and typing a `StringName` with nothing to check it against. That is how a move ends up bound to an animation that was never built, and how six Golden Pair moves ended up with no binding at all. The dock already knows every animation a character has and which moves lack a binding; it should be able to close the gap it reports.

`ResourceSaver.save()` cannot be used for this. Saving a presentation resource unchanged rewrites all 139 lines: it randomises every `ext_resource` id, adds entries for binding types the file does not use, and reorders the document. A one-line binding change would arrive as an unreviewable diff whose ids differ again on the next save, in the one file that four contributor roles share.
## Existing Behavior To Preserve
Every existing binding, sub-resource id, comment, and line stays untouched. The file keeps its authored `ext_resource` ids and ordering. Gameplay data, move sets, and built art are not touched. `ContentIndex` and the dock's read paths are unchanged.
## Required Change
Add a text-level writer that performs exactly two operations on a presentation `.tres`: rebind an existing move to a different animation key, and add an unconditional binding for a move that has none. After writing, the resource is reloaded and re-indexed; if it fails to load, or the character's error count rises, the original file content is restored.
## Public/API Contract
`BindingWriter.rebind(text, move_id, animation_key) -> Dictionary` and `BindingWriter.add_binding(text, move_id, animation_key) -> Dictionary`, each returning `{ "ok": bool, "text": String, "error": String }` and leaving the input untouched. Both are pure string transforms so they can be tested without the editor.
## Implementation Constraints
Write the smallest possible diff: one changed line to rebind, one inserted sub-resource block plus one array entry plus the `load_steps` count to add. Never reformat, reorder, or renumber anything else. The writer refuses rather than guesses whenever the file does not match the shape it expects: no `move_presentation_binding.gd` ext_resource, no `move_bindings` array, a duplicate binding, or a sub-resource id that is already taken. Resource-conditioned variants are out of scope and a move that has any conditioned binding is refused.
## Edge Cases
A move whose binding block is the last before `[resource]`; a `move_bindings` array that is currently empty; a move id that appears in both a binding and a projectile sub-resource; a character whose presentation file has no move bindings at all; a write that leaves the resource unloadable.
## Test Plan
Change type:
- feature

Expected test levels:
- static | unit | smoke

Pre-change expected failure / characterization:
`BindingWriter` does not exist, so a test asserting that rebinding changes exactly one line of a real presentation file fails to load.

Post-change required checks:
`python3 scripts/static_validate.py`, `bash scripts/verify.sh`.

## Acceptance Criteria
1. Rebinding an existing move changes exactly one line of the file.
2. Adding a binding inserts one sub-resource block, adds one array entry, and increments `load_steps`, leaving every other line byte-identical.
3. The writer refuses, with a message and no write, when the file does not match its expected shape or the move already has a conditioned binding.
4. After a write the resource is reloaded and re-indexed, and the file is restored if it fails to load or the character's error count rises.
5. The dock offers only animation keys that exist in the character's `SpriteFrames`.
6. Unit tests cover rebind, add, and each refusal, operating on real shipped presentation text.
7. `bash scripts/verify.sh` passes.
8. MANUAL, OUTSTANDING: a human uses the bind row in the editor and confirms the flow reads clearly and the status line is legible. Headless probes drove the write, verification, and rollback paths, but nobody has used this control.

## Rollback / Recovery Notes
Revert the branch. Files written by the dock are ordinary tracked `.tres` edits; `git checkout` restores them.

## Out of Scope
Resource-conditioned variants, state bindings, mode and effect bindings, removing a binding, editing gameplay data or move sets, and any reordering or reformatting of a presentation file.
