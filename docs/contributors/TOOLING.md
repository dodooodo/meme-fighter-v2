# Contributor Tooling

## Character content index

See [`CONTENT_INSPECTOR.md`](CONTENT_INSPECTOR.md). One read-only join over move
data, presentation bindings, and the built SpriteFrames answers "what does this
character have, and what will actually play".

```bash
./scripts/content_report.sh                      # full markdown report
./scripts/content_report.sh --issues-only        # verdict only, used by verify.sh
```

A binding naming an animation that is absent from SpriteFrames, or a move with
no binding at all, now fails CI. `MoveData.animation_id` does not bind anything;
the presentation binding does.

## Balance review

Use the read-only balance exporter described in
[`BALANCE_WORKFLOW.md`](../architecture/BALANCE_WORKFLOW.md). CSV is intended for
spreadsheet analysis; Markdown is intended for PR review. A3 does not provide a
write path from either format.

```bash
./scripts/export_balance.sh --format csv --output balance.csv
./scripts/export_balance.sh --format markdown --character salad_cat --output balance.md
```

## Evidence language

Every PR template separates actual evidence into `PASS`, `FAIL`, `NOT EXECUTED`,
or `N/A`. Choose `NOT EXECUTED` whenever a required runtime or human check did
not happen; source inspection is not a substitute.

## Art pipeline requirements

The builders need Python 3.9+ and Pillow. Pillow is not declared as a project
dependency and no CI job runs the builders, so a missing or too-old interpreter
surfaces only when you try to build.

Note that different Pillow versions re-encode frames to different bytes, and the
build manifest records a sha256 per frame, so rebuilding on a different Pillow
produces a real diff even when nothing else changed.

## One-command art build

Create one versioned JSON manifest and validate the complete batch before any
builder runs:

```bash
python3 scripts/build_art_manifest.py \
  --manifest assets/presentation/examples/art_build.example.json \
  --validate-only
```

Remove `--validate-only` to build every job in stable job-ID order. The wrapper
reuses the current normalization builders; it does not redefine crop, pivot,
frame, alpha, aspect-ratio, or output contracts.

Each job requires a unique lowercase `id` and one of these types:

| Type | Required fields | Existing builder |
| --- | --- | --- |
| `base_fighter` | `character`, `source` | `build_character_assets.py` |
| `mode_fighter` | `spec`; optional `source_root`, `output_root` | `build_mode_character_assets.py` |
| `effect` | `spec`; optional `source_root`, `output_root` | `build_effect_assets.py` |
| `ultimate_screen` | `spec`; optional `source_root`, `output_root` | `build_ultimate_screen_assets.py` |

All paths are repository-relative. Validation rejects unknown fields/types,
duplicate IDs, missing specs or source frames, path escapes, and pack-type
mismatches before execution begins. An explicit `output_root` must stay below
`assets/characters/<character_asset_key>/`; builders cannot rebuild arbitrary
repository directories. The wrapper validates the batch up front;
builder failures still stop the command immediately and may leave outputs from
earlier successful jobs, so review or commit generated output only after the
complete command reports `ART MANIFEST BUILD PASS`.

## Merge-conflict simulation

Run the isolated four-role simulation after contributor layout or ownership
changes:

```bash
python3 scripts/simulate_contributor_merges.py
```

The command creates a temporary local Git repository, copies representative
files for `magic_orange_cat`, commits Art, Balance, Frontend, and Skill branches
from one base, and merges them into an integration branch. It fails on missing
or overlapping paths, unexpected branch changes, a merge conflict, or a dirty
integration tree. It never creates or changes branches in the real repository.
