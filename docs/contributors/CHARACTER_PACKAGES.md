# Character Package Workflow

Use `content/characters/_template/` as the starting point for manifest-backed
characters. Copy it to `content/characters/<character_id>/`, replace the reserved
placeholder identity, author package-owned gameplay/presentation resources, and
register the finished manifest through `CharacterCatalog` at a frontend/content
composition boundary. Adding a character must not require edits to `battle/` or
`fighter/`.

Every package uses this shape:

```text
content/characters/<character_id>/
  character_manifest.tres
  gameplay/
    character.tres
    move_set.tres
    moves/*.tres
  presentation/character_presentation.tres
  assets/
```

`move_set.tres` references one external MoveData resource per move. At minimum,
author `stand_light`, `stand_heavy`, `crouch_low`, `air_attack`, `ground_throw`,
`special_neutral`, and `ultimate`. Keep the manifest, CharacterData, and
CharacterPresentationData IDs identical; give every move a unique stable ID,
valid frame data, valid cancel targets, and presentation art/animation bindings.

Run focused validation and tests while authoring:

```bash
./scripts/test_character.sh <character_id>
```

The package commands perform a headless editor import first so they also work
from a fresh checkout where Godot has not built its local class cache yet.

Run all package validation with:

```bash
./scripts/validate_characters.sh
```

Finish with the repository gate:

```bash
python3 scripts/static_validate.py
bash scripts/verify.sh
```

The reserved `_template` directory is inert: commands reject it and package
discovery skips directories whose names start with `_`.
