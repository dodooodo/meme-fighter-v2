# A-VS-003 — Golden Pair Presentation-Binding Remediation

Implementation date: 2026-08-22. Scope: roster `salad_cat` and
`magic_orange_cat` presentation resources only.

## Result

Both roster resources now explicitly map the required authoritative fighter
state keys and canonical move IDs to their existing production animation keys.
`FighterPresentationResolver` remains generic and read-only; its fallback
behavior is unchanged, but neither Golden Pair resource relies on it for the
covered states or moves.

| Coverage | Salad Cat | Magic Orange Cat |
| --- | --- | --- |
| Required states, including guard postures and charge | direct binding | direct binding |
| Normal, air, throw, special, and ultimate moves | direct binding | direct binding |
| Charged special L2/L3 | not a roster move | direct binding to `special_neutral` |
| Generic fallback | not used for covered keys | not used for covered keys |

Focused executable coverage loads the roster resources and verifies every
required state/move lookup against its expected animation key. This prevents a
future removal of a binding from silently regressing to `idle` or `attack`.

## Verification

- `python3 scripts/static_validate.py` — PASS (3650 passed, 0 failed).
- `python3 scripts/validate_task.py --task docs/tasks/active/A-VS-003.md` —
  PASS.
- Godot 4.7.2 stable editor import — PASS.
- `godot --headless --path . -s res://tests/run_tests.gd` — PASS.
- `bash scripts/verify.sh` — PASS, using the local ignored Godot 4.7.2 app.

## Preserved limitation

Salad Cat source frames 038–040 remain transparent, source-missing placeholders
from the supplied asset bundle. This task neither fabricates replacement art
nor changes the asset pipeline; the binding correction makes the authored
`walk_back` animation reachable while retaining that explicit source defect.
