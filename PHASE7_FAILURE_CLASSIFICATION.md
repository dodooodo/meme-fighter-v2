# Phase 7 — Full-suite failure classification

Baseline command: `godot --headless --path . --script res://tests/run_tests.gd`.

## Test harness errors fixed

| Suite | Test group | Actual | Expected | Classification | Action |
|---|---|---|---|---|---|
| M5 Projectile Spawn | post-spawn indexing | `active_projectiles()` was empty after a failed spawn assertion, then indexes 0/1 raised SCRIPT ERROR | one clear failed spawn assertion | TEST HARNESS ERROR | Added prerequisite guards; the failed spawn assertion is retained and no longer cascades into invalid indexing. |
| Shell verification | hidden Godot errors | assertion-only process could exit successfully with a runtime error in stdout/stderr | verifier must fail | TEST HARNESS ERROR | `scripts/verify.sh` now captures Godot logs and rejects the required error tokens; `tests/tooling/test_runtime_error_detection.sh` proves an injected Invalid call fails verification. |

## Historical expectation groups still failing

| Suite | Test group | Actual | Expected | Classification | Reason / required modernization |
|---|---|---|---|---|---|
| M2.4 Throw Mobility / Knockdown | guarded throw, THROWN/KNOCKDOWN/GETUP setup | legacy F+Heavy setup does not create the current formal throw capture | old single-frame chord and its old timer setup | STALE TEST | Rewrite setup through the current F+Heavy command path, then measure actual authoritative hold boundaries. |
| Snapshot Restore | Knockdown/GetUp setup | state is one pre-transition state | old fixed tick counts | STALE TEST | Replace literal setup counts with a transition-observed helper, preserving snapshot/replay assertions. |
| M3 Meter / M4 asymmetric / meter portions of M5 | meter totals | current authoring awards raw MoveData values | removed global x5 meter multiplier | STALE TEST | Update expectations to current MoveData values; do not restore the removed global multiplier. |
| M3 Moves / Cancel / Snapshot | generic Special entry, recovery, cancels | current charge/release and cancel path rejects the old setup | pre-charge Special timing and old meter assumptions | STALE TEST | Use current charge release frames and current meter values in each scenario. |
| Golden Pair Package / ContentIndex | Salad and Magic animation validation | inventory-bound presentation uses production binding data rather than local SpriteFrames names | local SpriteFrames animation-name validation | STALE TEST | Make package validator resolve production bindings for inventory-backed scenes. |
| M4 Rush / Asymmetric | rush Special/throw/attack-state cases | old input and meter assumptions do not produce the authored action | legacy command timing and x5 meter expectations | STALE TEST | Modernize scenario inputs and raw meter assertions. |
| M5 Projectile Spawn/Combat/Snapshot | Zone Special projectile timing/contact | old tap-release timing does not spawn the current charged special | old M8 charge-entry assumptions | STALE TEST after indexing fix | Rebuild fixtures with the current charge release path before asserting projectile timeline/contact. |
| M8 CPU Replay | context bind assertion | old replay fixture does not bind current context shape | retired setup contract | STALE TEST | Update replay fixture to current normalized context contract. |
| A5 Doge Package | four pivot/adapter assertions | `inventory_bound_fighter_visual.gd`, inventory binding, non-top-left adapter | old `production_fighter_visual.gd` / top-left pivot assumption | STALE TEST | Assert the accepted inventory-bound FEET_CENTER contract instead. |

## Current defects

No accepted Phase 1–6G gameplay defect has been proven by the focused current-contract suites. The 100 remaining monolithic assertions require the documented fixture/expectation modernization above before the full suite can be considered clean.
