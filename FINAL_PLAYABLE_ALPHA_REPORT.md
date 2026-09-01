# Meme Fighter V2 — Final Playable Alpha Report

## Acceptance

**PLAYABLE ALPHA = YES**

All Phase 1–10 acceptance gates were executed against the current workspace.
No gameplay retuning, new feature work, or asset regeneration was performed
during this closeout.

## Phase Status

| Phase | Scope | Status |
| --- | --- | --- |
| 1–1B | Runtime boot recovery and BattleScene readiness | PASS |
| 2 | 14-character frontend roster wiring | PASS |
| 3 | Fighter read facade; CPU, Training, Debug, Telemetry | PASS |
| 4 | Simulation-owned standard spawn and reset positions | PASS |
| 5 | Pink Finisher and Doge armor contract | PASS |
| 6A–6G | Character mechanic contract batches | PASS |
| 7–7B | Test modernization and runtime-error detection | PASS |
| 8 | Representative real BattleScene matches | PASS |
| 9 | 14×14 matrix and determinism stress | PASS |
| 10 | Final production validation | PASS |

## Project Boot and Frontend

- Godot headless import: PASS.
- Main scene (`ModeSelectScene`) load: PASS.
- Real Mode Select → BattleScene selection path: PASS.
- Real BattleScene representative matches: PASS.
- Parse Error / Compile Error / SCRIPT ERROR / Invalid call-property counts: **0**.

## Canonical 14-Character Roster

`alien_meow`, `doge`, `ya_mouse`, `tempura_penguin`, `goblin_love`,
`salad_cat`, `magic_orange_cat`, `blade_shield`, `pink_star`,
`sauce_stubble_dog`, `scared_cat`, `ok_meow_boss`, `niu_lai`, `bao_la`.

- Visible in frontend: 14 / 14.
- Selectable by P1: 14 / 14.
- Selectable by P2: 14 / 14.
- Authoritative CharacterData and presentation resolution: 14 / 14.
- CPU profile resolution: 14 / 14.
- Missing IDs: 0. Duplicate IDs: 0.

## Runtime Combat and Character Contracts

Real BattleScene smoke verified movement, guard, Light/Heavy/Low, normal
throw/throw tech, Special Lv1–Lv3, Ultimate, hit/block, KO, round flow, and
canonical reset in:

- Doge vs Alien Meow
- Pink Star vs Bao La
- Tempura Penguin vs Magic Orange Cat

The final full suite re-ran accepted Pink/Doge, Alien/Salad, YA/Sauce,
Penguin/Magic, Scared/Husky, Goblin/OK, Blade/Niu, and Bao contract coverage.
CPU, Training, DebugOverlay, and observational Telemetry suites passed.

## Snapshot, Replay, Matrix, and Determinism

- Snapshot capture/restore and normalized replay: PASS.
- Replay determinism suite: 17 passed / 0 failed.
- Matchup matrix: **196 / 196 PASS**, including mirrors.
- Each matrix pairing validated configuration, canonical spawn, both fighters,
  movement, Light/Heavy/Low, Special Lv1, Ultimate, reset, snapshot restore,
  and BattleStateHasher replay.
- Determinism stress: 10,000 authoritative ticks per run, run twice.
- Auxiliary snapshot/hash coverage observed: mechanics, modes, resources,
  statuses, projectiles, and temporary entities.

| Stress run | Final hash |
| --- | --- |
| A | `1fcdd9d93e7b682841d14add9d6f84e5c47d9b5b1d76559b972a08bca5cb0c22` |
| B | `1fcdd9d93e7b682841d14add9d6f84e5c47d9b5b1d76559b972a08bca5cb0c22` |

Result: identical hashes.

## Production Asset Binding

- Runtime binding suite: **2694 passed / 0 failed**.
- Characters covered: 14 / 14.
- RED bindings: 0.
- Gameplay Frame remains separate from Image Frame.
- Fighter alignment remains `FEET_CENTER`.
- Presentation remains observational-only.

## Final Verification

| Gate | Result |
| --- | --- |
| Full Godot suite | 7324 passed / 0 failed |
| Static validation | 5070 passed / 0 failed |
| Character validation | PASS: 4 packages |
| Content report | 0 errors / 11 warnings |
| Parse Error | 0 |
| Compile Error | 0 |
| SCRIPT ERROR | 0 |
| Invalid call / get / property | 0 |

The verification runner retains Phase 7 runtime-output detection, so hidden
Godot runtime errors are treated as failures.

## Environment-Only Warnings

- macOS Godot system CA certificate lookup warning.
- Sandboxed Godot editor-settings write warning.
- Sandboxed `user://logs` log-rotation write warning.

These warnings are host/sandbox diagnostics, not project Parse/Compile/SCRIPT
errors, and did not affect any acceptance command's exit status.

## Non-Blocking Future Work

- Review the 11 informational content-report warnings: partial mode-pack
  coverage, orphan inventory animations, and explicitly allowlisted
  presentation fallbacks.
- Continue Beta-only feature and balance work only from this accepted baseline.

