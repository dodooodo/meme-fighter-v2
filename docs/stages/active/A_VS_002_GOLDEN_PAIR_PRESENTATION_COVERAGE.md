# A-VS-002 — Golden Pair Presentation Coverage Matrix

Audit date: 2026-08-22. Scope: `magic_orange_cat` and `salad_cat` only.
This is a source-level coverage audit. It does not certify visual quality,
runtime playback, game feel, or human play review.

## Evidence key

- **S** — source/static evidence
- **R** — runtime evidence from the complete Godot CI runner
- **M** — manual visual evidence; not executed
- **Gap** — no production binding or named, safe fallback is currently proven

## Finding summary

Both characters have production `SpriteFrames` and manifests containing all 23
required animation keys. Their `CharacterPresentationData` resources point to
the correct production visual scenes, but contain no `state_bindings` or
`move_bindings`.

Consequently, `FighterPresentationResolver` requests its state fallback
`idle` for every unbound state. For every unbound move it requests `attack`,
which `ProductionFighterVisual` resolves to its generic `stand_light`
fallback. These are generic runtime safety fallbacks, not character-approved
production mappings. They must not be represented as complete coverage.

| Item | Magic Orange Cat asset | Salad Cat asset | Current runtime resolution | Classification | Follow-up |
| --- | --- | --- | --- | --- | --- |
| Idle | `idle` (12 frames) | `idle` (12 frames) | `idle` fallback equals available animation | S: available; M pending | A-VS-006 manual review |
| Walk forward / back | `walk_forward` (12), `walk_back` (13) | same | unbound state → `idle` | Gap | A-VS-003 binding remediation |
| Crouch / landing | `crouch` (6), `landing` (7) | same | unbound state → `idle` | Gap | A-VS-003 binding remediation |
| Jump | `jump` (11) | `jump` (11) | unbound state → `idle` | Gap | A-VS-003 binding remediation |
| Dash / backstep | `dash_forward` (7), `backstep` (6) | same | unbound state → `idle` | Gap | A-VS-003 binding remediation |
| Guard high / low | `guard_stand` (6), `guard_crouch` (6) | same | unbound state → `idle` | Gap | A-VS-003 binding remediation |
| Hit / block reaction | `hitstun` (7), `blockstun` (6) | same | unbound state → `idle` | Gap | A-VS-003 binding remediation |
| Thrown / knockdown / getup / KO | `thrown` (8), `knockdown` (9), `getup` (8), `ko` (12) | same | unbound state → `idle` | Gap | A-VS-003 binding remediation |
| Stand light / heavy / crouch low | `stand_light` (10), `stand_heavy` (15), `crouch_low` (11) | same | unbound move → `attack` → `stand_light` | Gap; only light happens to land on matching asset | A-VS-003 binding remediation |
| Air attack / ground throw | `air_attack` (14), `ground_throw` (14) | same | unbound move → `attack` → `stand_light` | Gap | A-VS-003 binding remediation |
| Special | `special_neutral` (25), `JPEG魔法陣` presentation name | `special_neutral` (25), `Salad Tornado` presentation name | unbound move → `attack` → `stand_light` | Gap | A-VS-003 binding remediation; A-VS-006 clarity review |
| Ultimate | `ultimate` (25), `喵蘇魯的召喚` presentation name | `ultimate` (25), `Ultimate Salad Burst` presentation name | unbound move → `attack` → `stand_light` | Gap | A-VS-003 binding remediation; A-VS-004 feedback pass |

## Traceable source evidence

- `presentation/characters/magic_orange_cat_presentation.tres`
- `presentation/characters/salad_cat_presentation.tres`
- `presentation/visuals/production/magic_orange_cat_visual.tscn`
- `presentation/visuals/production/salad_cat_visual.tscn`
- `assets/characters/magic_orange_cat/animations/manifest.json`
- `assets/characters/salad_cat/animations/manifest.json`
- `presentation/fighter/fighter_presentation_resolver.gd`
- `presentation/visuals/production/production_fighter_visual.gd`

The existing Godot CI run proves the global test runner executes, but it does
not prove that every Golden Pair animation key is resolved and played at
runtime. The required runtime and manual evidence remains open.

## Required next work

1. **A-VS-003 — presentation-binding remediation:** Add explicit Golden Pair
   state/move bindings and focused coverage that verifies every required key
   resolves without generic fallback. This is not a combat change.
2. **A-VS-004:** After bindings are direct, review hit/block/KO/ultimate
   feedback and presentation polish.
3. **A-VS-005:** Run the match soak after runtime coverage exists.
4. **A-VS-006:** Conduct the manual visual and game-feel checklist.

No row is promoted to production-ready solely because the source sprite files
exist.
