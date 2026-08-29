---
id: A-COL-009
stage: A
type: tooling
status: done
dependencies: [A-COL-008]
allowed_paths: [addons/, project.godot, data/content_index.gd, docs/]
forbidden_paths: [battle/, fighter/, frontend/, presentation/, content/, assets/, scripts/, tests/]
required_specs: [AGENTS.md, docs/contributors/CONTENT_INSPECTOR.md, docs/roadmap/PRODUCTION_ROADMAP.md]
required_checks: [python3 scripts/static_validate.py, bash scripts/verify.sh]
---
# Task
## Goal
Give contributors an in-editor view of what a character has: every move, the animation each one binds, the frames that animation actually plays, and which entries are broken or unbound.
## Context
`A-COL-008` made the join and the CI gate, but reading it still means running a CLI and reading markdown. Art and balance contributors work inside the Godot editor, and the question they ask most often — "what will this skill look like after my change?" — is answered by playing the animation, not by reading a key name. The report cannot do that; an editor dock rendering the real `SpriteFrames` can.
## Existing Behavior To Preserve
`ContentIndex`, `CharacterValidator`, `scripts/content_report.gd`, and `scripts/verify.sh` are unchanged. The dock is a read-only consumer of the same index, so it can never disagree with CI. No gameplay, presentation, or content resource is written.
## Required Change
Add an `EditorPlugin` at `addons/character_content_inspector` contributing a dock with a character list, Moves/States/Animations tabs, an issue list, and an animation preview driven by the character's real `SpriteFrames`. Enable the plugin in `project.godot`. Reserve, but do not implement, the art-pack import entry point.
## Public/API Contract
No script API is exported. The dock reads `ContentIndex.build(...)` and `CharacterValidator.load_unbound_allowlist()` only. `ContentIndex` gains one additive entry key, `sprite_frames`, holding the already-resolved `SpriteFrames` so the preview renders engine truth without a second copy of the scene-state walk. No existing key, signature, or severity changes.
## Implementation Constraints
Editor-only and read-only: no `class_name` that could collide with game classes, no write path to `.tres`, `.json`, or built art, and nothing the running game loads. Severity wording and issue codes come from `ContentIndex` rather than being restated. The dock must degrade rather than fail when a package has no visual scene or no build manifest.
## Edge Cases
A package with no presentation resource; an animation key present in the index but absent from `SpriteFrames`; a character with no built manifest JSON for fps/loop metadata; a move bound through several resource-conditioned variants; an empty selection on first open.
## Test Plan
Change type:
- tooling

Expected test levels:
- static | smoke

Pre-change expected failure / characterization:
None applicable. The dock adds no runtime behavior and no gameplay surface; the index it renders is already covered by `ContentIndexTests`.

Post-change required checks:
`python3 scripts/static_validate.py`, `bash scripts/verify.sh`. The editor-import step loads the enabled plugin, so a script or resource error in the addon fails verification.

## Documentation Impact
Expected:
- required

Affected docs:
`docs/contributors/CONTENT_INSPECTOR.md`, `docs/contributors/TOOLING.md`, `docs/roadmap/PRODUCTION_ROADMAP.md`.

## Acceptance Criteria
1. The plugin is enabled in `project.godot` and `godot --headless --path . --editor --quit` completes with no script or resource error from the addon.
2. The dock lists every non-template character package and marks those carrying error-severity issues.
3. Selecting a character shows its moves with the bound animation, frame data, and per-row status, including unbound and allowlisted-unbound rows.
4. Selecting an animation plays it from the character's real `SpriteFrames` at the manifest's fps and loop setting.
5. The Animations tab identifies animations no binding references.
6. The dock writes nothing: no content, asset, or configuration file changes as a result of using it.

## Rollback / Recovery Notes
Disable the plugin in `project.godot` and delete `addons/character_content_inspector`. Nothing else depends on it.

## Out of Scope
GUI art-pack import and any write path (`A-COL-010`), editing bindings from the dock, and producing the missing charge-level animations for the Golden Pair.
