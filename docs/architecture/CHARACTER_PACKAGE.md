# Character Package

## CURRENT

Gameplay characters live in `data/characters/*.tres`; move sets in
`data/move_sets/`; moves in `data/moves/`; presentation data in
`presentation/characters/`. `data/roster_registry.gd` is a frontend/test
registry containing central concrete preloads. There is no `CharacterManifest`,
`CharacterCatalog`, or `content/characters/<id>/` package yet.

`CharacterData.id` is the stable gameplay identity. `CharacterData` owns base
stats, movement, base boxes, `MoveSetData`, and optional typed mechanics.
`MoveSetData` owns an array of `MoveData`; `MoveData` owns immutable move rules.
`CharacterPresentationData` remains separate from gameplay data.

## TARGET

A package has one manifest as its discovery/metadata boundary and separates
gameplay, presentation, and visual assets. Planned shape (not current reality):

```text
content/characters/<id>/
  character_manifest.tres
  gameplay/character.tres
  gameplay/move_set.tres
  gameplay/moves/*.tres
  presentation/character_presentation.tres
  assets/
```

`CharacterManifest v1` owns `id`, `display_name`, `version`, gameplay resource,
presentation resource, portrait, icon, content pack ID, and availability. It is
metadata and discovery only: it does not become combat runtime state.

`data/character_manifest.gd` is the v1 schema introduced by A-MOD-001. Its
validation rejects empty metadata, missing gameplay/presentation references, and
identity mismatches; `CharacterData.id` remains the canonical gameplay identity.

`CharacterCatalog` is the package discovery boundary. Its target API is
`list_manifests`, `get_manifest`, `load_gameplay`, `load_presentation`, and
`register_pack`. It must not be a global combat registry or mutate a Fighter's
MoveRegistry.

`data/character_catalog.gd` provides this additive v1 boundary beside
`RosterRegistry`. Pack registration is all-or-nothing and rejects invalid
manifests, duplicate character IDs, and duplicate content-pack IDs.

Mechanics require typed, generic data/runtime contracts first. No package may
introduce a `character_id` switch in generic gameplay. Presentation binds by
stable identity and can fall back visibly when art is missing.

## MIGRATION

1. `A-MOD-001` introduces `CharacterManifest v1` without moving characters.
2. `A-MOD-002` introduces a catalog beside `RosterRegistry` and routes consumers
   incrementally; central preloads are not removed until equivalent coverage exists.
3. `A-MOD-003` migrates only `magic_orange_cat` and `salad_cat` as the Golden Pair.
4. Later tasks split/move resources and add the template/validator.

Every package change needs ID/resource validation and focused character tests.
Version manifest-compatible changes intentionally; incompatible formats require a
new version and explicit migration, never silent guessing.
