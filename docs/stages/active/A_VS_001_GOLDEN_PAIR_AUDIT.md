# A-VS-001 — Golden Pair Gameplay Coverage Audit

Audit date: 2026-08-22. Scope: `magic_orange_cat` and `salad_cat` only.
This is a source-and-CI evidence audit; it does not certify game feel or
production visual coverage.

## Evidence key

- **S** — source/static evidence
- **R** — runtime evidence from the complete Godot CI runner
- **M** — manual evidence required; not executed

The complete runner passed in Godot Verify CI run `32553549357`, including the
14×14 roster configuration smoke test (196 matchups), canonical move-resource
validation, 10,000-frame simulation stress, and replay determinism stress.

| Coverage item | Magic Orange Cat | Salad Cat | Traceable evidence | Remaining evidence |
| --- | --- | --- | --- | --- |
| Walk, crouch, jump | S/R | S/R | shared fighter simulation; roster matrix configuration smoke | M: input/feel review |
| Dash and backstep | S/R | S/R | shared fighter simulation; 10,000-frame stress | M: responsiveness review |
| Guard high/low | S/R | S/R | shared guard system; simulation stress | M: readable feedback review |
| Light, heavy, low | S/R | S/R | roster matrix validates canonical move IDs; Salad low has authored target-separation effect | M: animation/impact review |
| Air attack and throw | S/R | S/R | roster matrix validates canonical move IDs | M: spacing/visual review |
| Special | S/R | S/R | roster matrix validates `SPECIAL_NEUTRAL`; Orange JPEG-circle replacement is covered | M: clarity review |
| Ultimate | S/R | S/R | Orange five-step Cthulhu sequence; Salad three-step high/low sequence | M: screen/feedback review |
| Hit reaction, knockdown/getup, KO | S/R | S/R | shared round/combat simulation exercised by stress and matchups | M: presentation and recovery review |
| Snapshot/replay compatibility | S/R | S/R | roster snapshot/hash and replay compatibility suites; stress replay hash match | none at source/runtime level |
| Production visual coverage | not certified | not certified | no A-VS-001 visual assertion | A-VS-002 |

## Source references

- `tests/roster/test_roster_matrix.gd` validates each roster member's canonical
  move set and executes all 196 ordered roster matchups.
- `tests/characters/roster/test_magic_orange_cat.gd` covers Orange's JPEG-circle
  replacement group and five-step ultimate.
- `tests/characters/roster/test_salad_cat.gd` covers Salad's low positioning
  effect and three-step ultimate sequence.
- `tests/stress/test_simulation_stress.gd` provides the render-free 10,000-frame
  and replay determinism runtime checks.

## Follow-up gaps

No source or CI evidence can substitute for visual and human-play evidence.
The required follow-up work is already enumerated in the Stage A roadmap:
`A-VS-002` (presentation coverage), `A-VS-003` (art defects), `A-VS-004`
(game feel), `A-VS-005` (three-minute soak), and `A-VS-006` (manual feel
checklist). These need individual task packets and must not be inferred as
passed from this audit.
