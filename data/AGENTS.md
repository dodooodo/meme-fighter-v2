# Gameplay data rules

`data/` contains immutable gameplay configuration, not runtime state or
presentation assets. Prefer data additions over generic-core branches. Preserve
stable IDs and resource references; validate all changed resources. The current
layout is `data/characters`, `data/move_sets`, and `data/moves`; do not pretend
the future Character Package layout exists. See `../docs/architecture/CHARACTER_PACKAGE.md`.
