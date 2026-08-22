# Balance Workflow

## Current contract: export-only

`MoveData` resources are authoritative. A3 provides a deterministic, read-only
balance projection; spreadsheet import is deliberately **export-only** until the
validation and apply phases below are implemented as one reviewed task. Raw overwrite
of `.tres` files or direct replacement from spreadsheet rows is never
an acceptable import path.

Export the complete formal roster as CSV:

```bash
./scripts/export_balance.sh --format csv --output balance.csv
```

Export one character as Markdown:

```bash
./scripts/export_balance.sh --format markdown --character magic_orange_cat --output balance.md
```

Use `GODOT_BIN=/absolute/path/to/godot` when the pinned executable is not on
`PATH`. The command fails closed when Godot, a roster character, a move set, a
move, a stable ID, or the output destination is invalid.

## Export schema v1

The compound key is the pair of stable IDs `(character, move)`. Neither display
names nor resource paths are identity. Rows are sorted by that compound key.

| Column | Meaning | Writable in a future import? |
| --- | --- | --- |
| `character` | `CharacterData.id` stable ID | no |
| `move` | `MoveData.id` stable ID within the character | no |
| `startup` | startup simulation frames | yes |
| `active` | active simulation frames | yes |
| `recovery` | recovery simulation frames | yes |
| `damage` | maximum authored damage among the move and its per-hit payloads | yes, only with a later explicit multi-hit mapping schema |
| `hitstun` | maximum authored hitstun among the move and per-hit payloads | yes, with the same restriction |
| `blockstun` | maximum authored blockstun among the move and per-hit payloads | yes, with the same restriction |
| `meter` | meter cost; gains are intentionally not collapsed into this column | yes |
| `range approximation` | furthest forward edge of authored strike/throw boxes in local pixels; excludes projectile travel, areas, movement, and conditional reach | no, derived |

The scalar maximum for multi-hit fields makes the export useful for review but
is intentionally insufficient to identify which payload should be edited. A
future writable schema must add stable per-hit identity rather than guessing.

## Required round-trip protocol

A future importer must implement all of these gates; omitting any one is a
contract failure.

1. Export a versioned envelope containing schema version, source commit, source
   resource fingerprints, and stable IDs for every writable record.
2. Run schema validation before interpreting values. Reject unknown columns,
   missing required columns, locale-formatted numbers, floats in integer frame
   fields, out-of-range values, duplicate compound keys, missing source rows,
   unexpected added rows, and edits to identity or derived columns.
3. Resolve every stable ID to exactly one current resource. Resource paths are
   location metadata, never identity.
4. Compare source fingerprints and commit metadata. Reject stale exports or any
   resource changed since export; never merge by guessing.
5. Produce a deterministic diff preview grouped by character/move/field. The
   preview includes old value, proposed value, source resource, affected tests,
   and all validation warnings. Preview performs no write.
6. Require a separate explicit apply command bound to the preview digest and
   unchanged source revision. There is no `--force` route around validation.
7. Write only allowlisted fields through structured resource serialization to
   temporary files, validate the full candidate set, and atomically replace
   resources only after every candidate passes.
8. Run character validation, affected character tests, static validation, and
   required replay/determinism regressions. On failure, restore the original
   files and report a nonzero result.

In short: stable IDs, schema validation, and a diff preview are mandatory; raw overwrite
without validation is forbidden. Spreadsheet service integrations do
not change this contract.
