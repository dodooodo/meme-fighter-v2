# Character Package

## CURRENT

Most gameplay characters live in `data/characters/*.tres`; move sets in
`data/move_sets/`; moves in `data/moves/`; presentation data in
`presentation/characters/`. `data/roster_registry.gd` remains a test and legacy
compatibility registry. `magic_orange_cat`, `salad_cat`, `doge`, and `niu_lai`
are manifest-backed packages under `content/characters/`; the other ten formal
roster characters remain on central paths. Niu Lai keeps its existing Courage
gameplay contract while owning split moves and production presentation assets.

`CharacterData.id` is the stable gameplay identity. `CharacterData` owns base
stats, movement, base boxes, `MoveSetData`, and optional typed mechanics.
`MoveSetData` owns an array of `MoveData`; `MoveData` owns immutable move rules.
`CharacterPresentationData` remains separate from gameplay data.

## TARGET

A package has one manifest as its discovery/metadata boundary and separates
gameplay, presentation, and visual assets. The migrated packages use this
shape:

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
`discover_builtin()` scans non-reserved package directories in deterministic
sorted order and commits the discovered set atomically. A5 Character Select
uses this path directly, filters on manifest availability, and therefore does
not need a new central character switch when a package is added.

The Golden Pair package manifests reference package-owned gameplay,
presentation, move-set, and per-move resources. Each package move set contains
ten external `MoveData` references and embeds no moves. `RosterRegistry`
obtains those two entries through the manifests so existing consumers keep
their compatibility API while package discovery becomes authoritative for the
migrated pair.

The Doge package applies the same boundary to a mechanic-diverse character. It
owns eleven external moves, including all three charge releases and the Super
Doge replacement Heavy, plus explicit base/mode presentation bindings. The
former central Doge character, move set, and presentation resources are retired;
the compatibility registry now routes its Doge entry through the package.

`content/characters/_template/` is the inert, copyable authoring scaffold. Its
reserved directory name is excluded from playable package discovery, its
manifest is unavailable, and its `_replace_me` identities prevent accidental
registration. It includes the manifest, gameplay, seven canonical placeholder
moves, presentation bindings, and asset-placement guidance.

`CharacterValidator` performs deterministic, read-only package validation for
manifest identity, required resources and moves, frame/cancel rules, projectile
identity and spawn rules, and presentation art bindings. Run
`scripts/validate_characters.sh`; it discovers non-reserved package directories
in sorted order and exits nonzero on any missing manifest or validation error.
For a faster authoring loop, `scripts/test_character.sh <character_id>` validates
one packaged character and then loads its existing focused roster suite. The
command accepts exactly one non-reserved packaged ID and propagates validation,
lookup, usage, and test failures as nonzero exits.

Mechanics require typed, generic data/runtime contracts first. No package may
introduce a `character_id` switch in generic gameplay. Presentation binds by
stable identity and can fall back visibly when art is missing.

## MIGRATION

1. `A-MOD-001` introduces `CharacterManifest v1` without moving characters.
2. `A-MOD-002` introduces a catalog beside `RosterRegistry` and routes consumers
   incrementally; central preloads are not removed until equivalent coverage exists.
3. `A-MOD-003` migrates only `magic_orange_cat` and `salad_cat` as the Golden Pair.
4. `A-MOD-004` splits the Golden Pair moves into package-owned resources.
5. `A-MOD-005` adds the inert package authoring template.
6. `A-MOD-006` adds deterministic package validation and its headless command.
7. `A-MOD-007` adds the focused per-character test command and contributor workflow.
8. `A-MVP-001` through `A-MVP-004` migrate Doge, split its moves, bind production
   presentation, and retain charge/snapshot/replay behavior through the package.
9. Niu Lai packages its Courage gameplay and recovered per-action production art.

Every package change needs ID/resource validation and focused character tests.
Version manifest-compatible changes intentionally; incompatible formats require a
new version and explicit migration, never silent guessing.

Niu Lai is the first package built from recovered per-action folders rather
than the legacy ten-sheet grid. Its 112 transparent source frames are
inventoried in one presentation manifest and composed into runtime animation
keys. Generic resource-conditioned presentation bindings read authoritative
Courage state but never write gameplay state.
