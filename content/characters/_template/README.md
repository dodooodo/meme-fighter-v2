# Character Package Template

Copy this directory to `content/characters/<character_id>/`, then replace every
`_replace_me` value and fill the gameplay, presentation, and asset bindings.
The reserved `_template` directory is never registered or validated as playable
content.

Authoring order:

1. Give the manifest, gameplay resource, and presentation resource the same stable ID.
2. Author one MoveData `.tres` per move under `gameplay/moves/`.
3. Reference those resources from `gameplay/move_set.tres`; do not embed MoveData there.
4. Add every required move and its animation/art binding.
5. Register the finished manifest with `CharacterCatalog`; combat-core edits are not required.
6. Run the repository verification gate before submitting the package.

The seven supplied moves are structural placeholders, not balanced gameplay.
