# TWO BOX FIGHTING — M6 COMPLETE Implementation Report

## 1. Baseline / Environment

- Input: `two_box_fighting_godot_m5_complete(1).zip`
- Expected SHA-256: `3b3cecdc7904eb8838b7ec816be4c7a44510520e14ac610f60329bb1a4fa39eb`
- Actual SHA-256: `3b3cecdc7904eb8838b7ec816be4c7a44510520e14ac610f60329bb1a4fa39eb`
- SHA: PASS
- Input ZIP `unzip -t`: PASS
- `godot`: UNAVAILABLE
- `godot4`: UNAVAILABLE
- Godot runtime: NOT EXECUTED — external verifier required

## 2. Architecture Audit / Prior Defect

M5 already had one fixed-tick `BattleSimulation`, normalized `InputFrame` sampling, per-Fighter runtime/input history, a battle-owned `ProjectileSystem`, snapshot v5 over Fighters + projectile serial/entities, and `BattleStateHasher`. Reset responsibility existed only as full scene reconfiguration; there was no deterministic round lifecycle/reset seam and no replay input seam.

One prior source/runtime-test compatibility defect was found during M6: existing M5 tests use `MeterComponent.set_value()`, while production `MeterComponent` exposed only restore/reset/gain/spend methods. M6 adds a minimal `set_value()` alias to the existing clamped restore setter. No meter gameplay policy changed.

## 3. M6 Match / Round Result

`MatchRulesData` is immutable configuration with stable IDs. Prototype resources are:

- Versus `versus`: first-to-2; timer enabled; 5940F; 90F post-round; match can end; meter resets each round.
- Training `training`: rounds_to_win 0; timer disabled; timer value 0; 60F post-round; match cannot end; meter resets on KO cycle reset.

`RoundController` is a small `RefCounted` component owned/ticked only by `BattleSimulation`. Runtime states are `ROUND_ACTIVE`, `POST_ROUND`, `MATCH_OVER`; results are `NONE`, `P1_WIN`, `P2_WIN`, `DRAW`. All same-frame combat outcomes apply before KO/timeout evaluation. KO takes priority over timeout; timeout uses post-apply HP. Gameplay hitstop freezes the integer timer.

The round-ending tick enters POST_ROUND with the full configured countdown. Later POST_ROUND ticks neutralize player input and build no new combat contacts/spawns while allowing deterministic KO/air/reaction settlement. Round reset restores Fighter HP/runtime/input/position/facing/meter and clears active projectiles. Projectile instance serial remains monotonic inside one Match; explicit full-match reset resets serial and the global simulation frame.

Training uses the same BattleSimulation/RoundController and only changes MatchRulesData. It has no timer, no score, no permanent MATCH_OVER, and auto-resets after 60F following KO.

## 4. Snapshot / Hash

Battle snapshot schema is v6. `RoundStateSnapshot` captures stable rules ID, round state/number, P1/P2 wins, timer, post-round timer, result, pending winner, final winner. Restore rejects rules-ID mismatch before mutation and clears non-gameplay presentation events afterward. Existing Fighter character identity and projectile rehydration contracts remain.

`BattleStateHasher` canonical order is version/frame → Match/Round → P1 Fighter → P2 Fighter → projectiles. Every future-affecting RoundController field is included; Replay tooling is excluded.

## 5. Replay Foundation

M6 Replay is normalized-input reconstruction, not state recording.

- `ReplayFormat`: schema 1, combat-rules version 1, stage `greybox_stage`, `.tbf_replay.json`.
- `ReplayData`: versions, rules ID, stage ID, P1/P2 character IDs, random seed slot, initial simulation frame, ordered complete frame pairs, expected final BattleStateHasher String.
- `ReplayFramePair`: absolute simulation frame + copied P1/P2 InputFrames.
- `ReplayRecorder`: observes final authoritative consumed InputFrames after Match/Round gating; rejects duplicate/gap/out-of-order frames; finish is one-shot.
- `ReplayInputSource`: implements existing InputSource and performs random-access lookup by authoritative frame number; EOF returns neutral with diagnostic state.
- `ReplayValidator`: validates already-configured rules/characters/stage/version and final hash; never auto-loads CharacterData/MatchRules.
- `ReplayCodec`: explicit scalar JSON + optional FileAccess persistence only; no Resource/Node/instance serialization or arbitrary resource loading.

Fresh-Battle deterministic replay tests are authored with Zone vs Rush, projectile reconstruction, round transition, dash reconstruction, metadata rejection and final BattleStateHasher equality.

## 6. Files Added

- `battle/match/round_controller.gd`
- `battle/replay/replay_codec.gd`
- `battle/replay/replay_data.gd`
- `battle/replay/replay_format.gd`
- `battle/replay/replay_frame_pair.gd`
- `battle/replay/replay_input_source.gd`
- `battle/replay/replay_recorder.gd`
- `battle/replay/replay_validator.gd`
- `battle/simulation/round_state_snapshot.gd`
- `data/match_rules_data.gd`
- `data/match_rules/versus_match_rules.tres`
- `data/match_rules/training_match_rules.tres`
- `tests/match/test_milestone_6_round_flow.gd`
- `tests/match/test_milestone_6_timeout.gd`
- `tests/match/test_milestone_6_training.gd`
- `tests/replay/test_replay_data.gd`
- `tests/replay/test_replay_input_source.gd`
- `tests/replay/test_replay_codec.gd`
- `tests/replay/test_replay_determinism.gd`
- `tests/snapshot/test_milestone_6_match_snapshot.gd`

## 7. Files Modified

- `ARCHITECTURE.md`
- `CONTRIBUTING_AI.md`
- `IMPLEMENTATION_REPORT.md`
- `README.md`
- `VALIDATION_REPORT.txt`
- `battle/battle_scene.gd`
- `battle/battle_scene.tscn`
- `battle/battle_simulation.gd`
- `battle/projectiles/projectile_system.gd`
- `battle/simulation/battle_snapshot_codec.gd`
- `battle/simulation/battle_state_hasher.gd`
- `battle/simulation/battle_state_snapshot.gd`
- `debug/combat_logger.gd`
- `debug/debug_overlay.gd`
- `fighter/combat/hitbox_owner.gd`
- `fighter/fighter.gd`
- `fighter/meter/meter_component.gd`
- `fighter/moves/move_runner.gd`
- `presentation/battle_hud.gd`
- `scripts/static_validate.py`
- `tests/debug/test_frame_stepper.gd`
- `tests/run_tests.gd`
- `tests/snapshot/test_milestone_5_projectile_snapshot.gd`
- `tests/stress/test_simulation_stress.gd`

Files deleted: None.

## 8. Tests / Stress / Static

M6 adds 32 `_test*` functions and 179 assertion-call sites relative to the M5 baseline. Whole project inventory is 212 `_test*` functions and 1208 assertion-call sites. Eight new M6 suites are preloaded/executed by `tests/run_tests.gd`; FrameStepper and Stress suites were expanded in place.

The 10,000F stress source remains exactly 10,000 general simulation ticks across Generic, Rush, Zone, projectile, Round/Match transitions, snapshot integrity and deterministic full-match resets. A separate 1,800F Replay stress records authoritative InputFrames, plays them into a fresh Battle, and compares final BattleStateHasher state.

Actually executed source/static result before packaging:

```text
python3 scripts/static_validate.py
1588 passed
0 failed
```

Godot runtime tests/stress are authored and runner-wired but were not executed in this environment.

## 9. M5 Gameplay Regression

SHA comparison against the formal M5 baseline confirms all 26 protected gameplay data resources are byte-for-byte unchanged:

- 3 CharacterData resources
- 21 MoveData resources
- 2 ProjectileData resources

M5 projectile rules (F15/F19 spawn, spawn-frame movement rule, origin-side guard, multiple entities, owner-KO same-frame outcome ordering, rehydration) remain protected by existing tests/static checks.

## 10. Breaking Changes / Boundary

- Battle snapshot schema v5 → v6.
- BattleSimulation now owns RoundController and optional ReplayRecorder observation seam.
- BattleScene default binds Versus MatchRules.
- Fighter/MoveRunner/HitboxOwner/ProjectileSystem gain narrow reset/cleanup APIs.
- `MeterComponent.set_value()` compatibility alias added; no meter semantics changed.

M6 does not implement Round/Result presentation, Training UI, Replay seek/checkpoints/video, CombatDataHash/cross-build compatibility, Touch UI, Online/rollback networking, Character 4, Beam/Trap/Summon, or presentation overhaul.

Existing architecture debt remains: float Rect2/Vector2 collision representation, possible float horizontal knockback damping, standing hurtbox while crouched, no formal block pushback, GetUp state-level protection, and no cross-platform determinism audit.

New architecture debt: None identified.

## 11. External Verification Handoff

```bash
godot --version
godot --headless --path . --editor --quit
godot --headless --path . -s res://tests/run_tests.gd
./scripts/verify.sh
```

Target runtime is Godot 4.7.2. Until those commands are actually executed, Runtime PASS is not claimed.


# M7 COMPLETE — Presentation Foundation Implementation Addendum

## Architecture result

M7 keeps `BattleSimulation` authoritative and adds a BattleScene-owned `BattlePresentationController`. Presentation state is intentionally outside gameplay Snapshot/Hash/Replay truth. `CombatEvent` gained only stable scalar provenance and Round presentation event kinds; combat result semantics and simulation ordering are unchanged.

Implemented presentation components include typed Character/Move/State/Projectile presentation bindings, greybox Fighter/Projectile visual adapters, generic Fighter state/move resolver, centralized simulation-to-pixel converter, ProjectileInstanceID visual cache, HUD view model/UI, Round overlay, deterministic presentation event ID + ledger, placeholder VFX, audio cue hooks, camera follow/shake, and scene-level resync/reset hooks.

## Versioning

- Battle Snapshot remains v6.
- Replay schema remains 1.
- Combat rules version is 2 because the M6 POST_ROUND asymmetry fix changes deterministic gameplay output; Presentation itself adds no gameplay rule change.
- BattleStateHasher receives no presentation state.

## Tests

Eight M7 presentation suites are wired into `tests/run_tests.gd`, covering data identity/duplicates, state/move resolution, render mapping, projectile visual lifecycle, HUD/Round overlay, deterministic event identity/ledger, VFX/audio/camera dedupe, headless/gameplay separation, snapshot-resimulation identity, and Replay event/hash regression.

Godot runtime is not available in the coding environment, so runtime PASS is not claimed. Source/static validation and packaging results are recorded in `VALIDATION_REPORT.txt` and the external final report.

## M7 Final Source Inventory

Relative to the formal M6 baseline, M7 adds 34 files and modifies 16 files; no files are deleted. M7 contributes 20 net `_test*` functions and 70 net assertion call sites. Whole-project source inventory is 232 `_test*` functions / 1278 assertion call sites. Final static validation is 2182 passed / 0 failed.

Independent SHA regression confirms 28 protected M6 gameplay data resources are byte-for-byte unchanged: 3 CharacterData, 21 MoveData, 2 ProjectileData, and 2 MatchRulesData resources. Snapshot stays v6; Replay schema stays 1; combat-rules version is 2 for the documented M6 POST_ROUND gameplay fix.

One prior M6 defect was fixed during M7: `_simulate_post_round_tick()` had an accidental duplicate P1 `movement_tick()` call. M7 restores one settlement tick per Fighter and adds a symmetric mirror regression test. This fix is independent of Presentation and does not change character/move/projectile/rules data.

# M8 — Solo Playtest + Core Combat Alignment Addendum

## 1. Baseline

Formal source baseline is the M7 Production Character Fixpass package. Pre-change static validation was `2724 passed / 0 failed`. `bash scripts/verify.sh` reached the same static result and reported Godot Runtime not run because no Godot executable exists in this environment. Direct `./scripts/verify.sh` on the extracted baseline returned permission denied because the ZIP did not preserve the executable bit; this is recorded as a packaging permission condition, not a gameplay failure.

## 2. M8A Match Mode

`frontend/mode_select_scene.tscn` is now the project main scene. It offers only `1P VS CPU` and `2P LOCAL`. `BattleMode` carries the selection, while `BattleInputWiring` owns the exact existing desktop key mapping. Reset (`R`) rebuilds the battle with the same mode; `Esc` returns to Mode Select. Match mode affects input source construction only.

## 3. M8A CPU Architecture

`CpuInputSource` extends the existing `InputSource`. It receives read-only references to its own Fighter, opponent Fighter and BattleSimulation after simulation configuration, then emits canonical `InputFrame` values. It never calls Fighter mutation, MoveRunner start, HFSM transition, CombatResolver, ProjectileSystem mutation or keyboard polling.

CPU v1 is deterministic rules-based playtest infrastructure, not final AI. New decisions are evaluated at 8F boundaries. Distance bands are 12000 / 26000 simulation units. The controller can walk, back away, stand/crouch guard, Light, Heavy, low, Forward+Heavy throw, jump, occasional direction-history dash, Special and meter-gated Ultimate. Variation comes from a fixed integer mix of decision block, fighter ID, seed and salt; no runtime RNG or wall clock is used.

## 4. M8B Charge Runtime

`ChargeSpecialData` is immutable configuration attached optionally to MoveData. Generic/Rush/Zone canonical `special_neutral` entries all define Lv2=24F, Lv3=54F and stable `special_neutral_l2/l3` release IDs.

FighterStateMachine owns the mutable generic CHARGE state. Press enters CHARGE at F1, held input increments on non-hitstop gameplay ticks, and release resolves the target through that Fighter's MoveRegistry before using the normal MoveRunner start path. Lv3 never auto-releases. Charge is grounded/immobile/facing-locked and is cleared by hit, throw, KO and reset.

Heavy->Special cancel interrupts the old AttackInstance and enters CHARGE if the existing cancel window allows canonical Special. No Special attack exists until release. Generic/Rush release moves can retain their own Special->Ultimate CancelWindowData. Zone keeps its prior no-Special->Ultimate cancel contract.

## 5. Prototype Character Data

- Generic Lv1 keeps the previous canonical Special data; Lv2/Lv3 increase range/damage/knockback, with Lv3 knockdown.
- Rush Lv1 keeps its prior canonical values and gains generic deterministic travel data; Lv2/Lv3 increase travel/range/reward without Armor.
- Zone Lv1 keeps the prior Zone Shot descriptor; Lv2/Lv3 use new `zone_shot_l2/l3` ProjectileData through the existing ProjectileSystem. No ZoneSpecialSystem was created.

## 6. Snapshot / Hash / Replay

Battle snapshot schema is v7. Fighter snapshots add `charge_frames`, `charge_entry_move_id`, and `charge_locked_facing`. Restore validates/re-resolves the charge entry via MoveRegistry; no MoveData/ChargeSpecialData Resource pointer is serialized. BattleStateHasher hashes the same values.

Replay schema remains v1 and still stores only normalized P1/P2 InputFrames. CombatRulesVersion is v3 because M8 changes how Special input is interpreted. CPU decisions and derived Charge level are not replay payload.

## 7. Tests

Three M8 suites are registered in `tests/run_tests.gd`: CPU/Input wiring and deterministic stress, Charge mechanics/snapshot/cancel/projectile paths, and CPU/Charge replay determinism. Existing tests were retained; prior tests whose direct one-frame Special tap assumed immediate attack start were aligned to the deliberate M8 `press -> CHARGE -> release -> Lv1` input semantics without changing their underlying frame-data/combat assertions.

## 8. Presentation

M8 adds only development visibility for CHARGE through presentation bindings/debug summaries. Production artwork remains presentation-only. No animation/VFX determines charge level or gameplay timing.

## 9. Deferred

Armor, Install, Summon, Counter, expanded formal roster, Character Select, Touch UI, Online/rollback, lobby/matchmaking/rank/story, and final production AI are explicitly deferred.

---

## M9P — Multi-Pack Production Presentation Pipeline

Implemented Presentation-only asset domains and tooling:

- Backward-compatible `BASE_FIGHTER` manifest v3 (`pack_type=BASE_FIGHTER`, `mode_id=""`).
- Manifest-driven `MODE_FIGHTER` builder with variable frame count, rectangular source support, tight-pivot output and FEET_CENTER metadata.
- Arbitrary-aspect `PROJECTILE`, `WORLD_EFFECT`, `HAZARD`, and `ATTACHMENT` builder with individual-frame / explicit strip / explicit grid input.
- `ULTIMATE_SCREEN` builder targeting 1280×720 with aspect-preserving 16:9 normalization.
- Typed Presentation resources for mode, effect, ultimate and attachment bindings.
- Mode visual swap API that replaces only Fighter Presentation children.
- Rectangular Production world/projectile visuals, world effect presenter, Ultimate screen presenter, and attachment helper.
- Multi-pack Development preview UI.
- Expanded Presentation validator/static architecture guards and M9P test inventory.
- Production art contract and per-character requirement documents for Salad Cat, Doge, Magic Orange Cat, and Pink Star.

No M9P feature defines gameplay damage, collision, frame data, input, charge behavior, CPU decisions, Snapshot truth, Replay truth, or BattleStateHasher state.
