# Two Box Fighting — M7 Complete — Presentation Foundation

Implementation status: **M6 IMPLEMENTATION COMPLETE**  
Godot runtime verification: **NOT EXECUTED — external verifier required**

Godot 4.x greybox 2D 1v1 fighting framework. Gameplay is an authoritative fixed-tick simulation with normalized InputFrames, data-driven three-character combat, detached deterministic projectiles, MatchRules-driven Round lifecycle, snapshot v6, and same-build input-only Replay foundations. Presentation/debug reads gameplay truth; it does not own Round, Replay, or combat decisions.

M6 adds deterministic Versus/Training MatchRules, RoundController lifecycle, round reset/temporary-entity cleanup, round/match snapshot+hash state, normalized InputFrame replay recording/playback, explicit JSON replay codec, and fresh-Battle final-hash verification. It does not add Character 4, result/round presentation, Training UI, Touch, Online, or rollback networking.

## Controls

## Run Locally (revision 2026-08-22)

This project requires **Godot 4.7.2 stable**. This is the supported runtime for
local development and CI; do not substitute a development, release-candidate,
or newer Godot build without an explicit runtime-version task.

From the project root (the directory containing `project.godot`), run the game directly:

```bash
godot --path .
```

On the macOS machine used for this project, the exact command is:

```bash
/opt/homebrew/bin/godot --path /absolute/path/to/two_box_fighting_godot
```

To launch it from Finder/Application Services instead of a terminal on macOS:

```bash
open -n -a Godot --args --path /absolute/path/to/two_box_fighting_godot
```

If `godot` is not on your `PATH`, replace it with the absolute path to your
Godot 4.7.2 executable. Do not add `--editor` when you want to play: `--editor`
opens the project editor rather than the game.

The canonical local and CI verification command is:

```bash
bash scripts/verify.sh
```

It fails closed when Godot is unavailable. It runs the same commands in the
same order locally and in CI: static validation, the pinned Godot version,
headless editor import, then the headless runtime test runner.

To run the individual headless commands for diagnosis from the same project
root:

```bash
python3 scripts/static_validate.py
godot --version
godot --headless --path . --editor --quit
godot --headless --path . -s res://tests/run_tests.gd
```

Current local tuning: character HP is `5000`, and positive Meter gains are multiplied by `5`; Meter capacity and Meter costs are unchanged.

P1 desktop development mapping is permanently:

```text
W = Up / Jump
A = World Left
S = Down / Crouch
D = World Right

U = LIGHT
I = HEAVY
J = GUARD
K = SPECIAL
L = ULTIMATE
```

Derived gameplay commands:

```text
Forward + I                 = Ground Throw
S + J                       = Crouching Guard
Forward -> Neutral -> Forward = Dash Forward
Back -> Neutral -> Back       = Backstep
Air U / Air I               = Air Attack
Ground K                    = Special Neutral
Ground L                    = Ultimate (requires 100 Meter)
```

Combat Core never reads W/A/S/D/U/I/J/K/L. Physical keycodes are isolated to `KeyboardInputSource`; combat consumes normalized `InputFrame` direction plus `LIGHT`, `HEAVY`, `GUARD`, `SPECIAL`, and `ULTIMATE` bits.

## Existing M2 Greybox Core Preserved

- Walk Forward / Walk Back / Crouch
- Stand Light — 5F / 3F / 10F, 50 damage
- Stand Heavy — 11F / 4F / 20F, 95 damage
- Crouch Low — 8F / 3F / 16F, 60 damage, LOW
- Standing / Crouching Guard, HIT / BLOCK, Hitstun / Blockstun / Hitstop
- Jump, integer gravity, air steering, landing, one Air Attack per jump
- Air Attack — 6F / 4F / 12F, 70 damage, HIGH
- Cross-over, end-of-tick facing, attack-facing lock
- Dash Forward / Backstep from facing-relative double taps
- Ground Throw, Throw whiff, THROWN -> KNOCKDOWN -> GETUP
- Same-frame trade ordering and AttackInstance duplicate-contact protection
- 5F contextual ActionIntent buffer and 60F InputHistory
- Snapshot / restore / deterministic debug hash foundation

## Meter

Each Fighter owns a deterministic integer `MeterComponent`:

```text
Minimum = 0
Maximum = 100
```

Meter is gameplay runtime state, not HUD state or mutable CharacterData. Move cost and reward values live on `MoveData`.

Prototype rewards:

| Move | HIT | BLOCK | THROW |
|---|---:|---:|---:|
| Stand Light | +8 | +4 | 0 |
| Stand Heavy | +12 | +6 | 0 |
| Crouch Low | +10 | +5 | 0 |
| Air Attack | +10 | +5 | 0 |
| Ground Throw | 0 | 0 | +15 |
| Special Neutral | +18 | +8 | 0 |
| Ultimate | 0 | 0 | 0 |

Meter is awarded only from authoritative resolved/appplied combat outcomes. Duplicate-contact protection therefore also prevents duplicate Meter gain. The defender receives no Meter in M3.

## Special Neutral

Stable Move ID: `special_neutral`

```text
Startup:        10F
Active:          4F
Recovery:       18F
Actionable:     F33
Damage:         110
Hitstun:         20F
Blockstun:       14F
Hitstop:          6F / 6F
HitLevel:        MID
Knockback X:    1100 sim units
Knockback Y:       0
Meter Cost:        0
Meter Gain HIT:  +18
Meter Gain BLOCK: +8
Hitbox offset:   Vector2(82, -76)
Hitbox size:     Vector2(120, 88)
```

It is a grounded data-driven strike. There is no projectile, armor, invulnerability, movement override, cinematic dependency, or air version.

## Ultimate

Stable Move ID: `ultimate`

```text
Startup:        14F
Active:          5F
Recovery:       32F
Actionable:     F52
Damage:         260
Hitstun:         28F
Blockstun:       18F
Hitstop:         10F / 10F
HitLevel:        MID
Knockback X:    1600 sim units
Knockback Y:    -500 sim units
Meter Cost:      100
Meter Gain:        0
Hitbox offset:   Vector2(94, -82)
Hitbox size:     Vector2(154, 108)
```

The Meter gate is checked before the move starts. A successful start immediately spends 100 and never refunds it, even on whiff or interruption. M3 Ultimate has no cinematic, super flash gameplay freeze, invulnerability, armor, projectile, or time-scale behavior.

## Cancel / Combo Routes

Cancel windows are typed `CancelWindowData` Resources stored on `MoveData`. `MoveRunner` understands only generic move data, current frame, AttackInstance identity, and whether the current attack instance has connected as HIT and/or BLOCK.

Prototype routes:

```text
Stand Light -> Stand Light
  F6-F12, ON_HIT_OR_BLOCK, no Meter cost

Stand Light -> Stand Heavy
  F6-F12, ON_HIT_OR_BLOCK, no Meter cost

Stand Heavy -> Special Neutral
  F12-F20, ON_HIT_OR_BLOCK, no Meter cost

Special Neutral -> Ultimate
  F11-F18, ON_HIT only, target still requires 100 Meter
```

Whiff does not satisfy HIT/BLOCK conditions. Crouch Low, Air Attack, Ground Throw, and Ultimate have no M3 cancel routes.

Terminology:

- **Link**: previous move fully recovers; next move starts through normal actionable-state logic.
- **Cancel**: current move ends early because an active `CancelWindowData` permits the target.
- **Chain**: M3 treats Normal -> Normal as a data-defined Cancel; there is no separate ChainSystem.

A successful Cancel starts the target through the same MoveRegistry/MoveData/MoveRunner path and receives a new AttackInstance ID. It does not create a zero-frame target move or re-run collision recursively in the same combat-resolution phase.

## Input Priority and Guard

When multiple action-button press bits exist in one InputFrame, parser priority is deterministic:

```text
ULTIMATE > SPECIAL > HEAVY > LIGHT
```

If HEAVY is selected, existing Forward + Heavy Throw precedence remains intact through `ActionMoveMap`.

Guard remains higher-priority state behavior. Holding Guard does not allow buffered Special or Ultimate to bypass Guard. Forced reactions clear inappropriate offensive buffers; Blockstun retains the existing generic 5F buffering contract.

## Snapshot / Restore / Hash

M3 raises the gameplay snapshot schema to **version 3** and adds all new mutable gameplay state:

- Fighter Meter integer value
- MoveRunner `connected_hit`
- MoveRunner `connected_block`
- existing current move stable ID / move frame
- existing AttackInstance ID / next serial
- existing contact registry
- all existing Movement, Combatant, HFSM, InputBuffer, and complete InputHistory state

Static Resources, Node pointers, presentation state, Debug Overlay, and CombatLogger are not serialized. Current MoveData is restored via stable `current_move_id -> MoveRegistry.get_move()`.

`BattleStateHasher` includes the M3 fields in explicit canonical order.

## Debug Controls

```text
F1 = Gameplay boxes
F2 = Debug overlay
F3 = Pause / Resume simulation
F4 = Advance exactly +1 simulation frame
F5 = Advance exactly +5 simulation frames
R  = Reset greybox battle
```

F1 automatically displays Special / Ultimate static hitboxes through the generic hitbox debugger.

F2 includes existing simulation state plus:

```text
Meter: X / 100
Current Move Connected: NONE / HIT / BLOCK
Cancel Window: active / inactive
Cancel Targets: ...
```

`CombatLogger` remains sparse and debug-only; it can record Meter gain/spend and accepted / Meter-denied cancels without becoming gameplay authority.

## M4 COMPLETE — Second Character Framework Validation

The development scene now runs an asymmetric greybox match: P1 `generic_fighter`, P2 `rush_grappler`. Both use the same Fighter/Input/HFSM/Movement/MoveRunner/Combat/Throw/Meter/Snapshot runtime. Rush Grappler is data-only and uses the same seven canonical Move IDs with different frame data, boxes, movement, throw rewards, Meter rewards, and cancel graph.

Key M4 architecture results:

- CharacterData's existing `id` field is the stable immutable character identity.
- Each Fighter owns a MoveRegistry built from its own MoveSetData.
- The same `stand_light` ID resolves to Generic Light or Rush Light depending on the owning Fighter.
- Snapshot schema v4 captures character identity, rejects cross-character restore, and rehydrates current moves through the correct Fighter registry.
- BattleStateHasher includes stable textual character identity.
- No Rush-specific Fighter class, generic combat character branch, Projectile subsystem, or CharacterMechanicRuntime was added.

Rush movement profile: Forward Walk 345, Back Walk 252, Jump -1350, Gravity 85, Max Fall 1850, Air Forward 270, Air Back 225, Landing 2F, Dash 7F/1050/3F, Backstep 6F/850/5F.

M4 runtime test source is registered in `tests/run_tests.gd`, including character data/registry, Rush combat/cancel/throw, asymmetric combat/trades, snapshot identity/rehydration, and the updated 10,000F multi-character stress source.

## Validation Status in This Package

This implementation environment does not provide `godot` or `godot4`. Runtime results are therefore intentionally not claimed.

Actually executed during M4 implementation:

```text
python3 scripts/static_validate.py
Static validation: 1003 passed, 0 failed

bash -n scripts/verify.sh
PASS

./scripts/verify.sh
Static: PASS
Godot Runtime: NOT RUN — executable unavailable
```

Runtime-test source inventory:

```text
25 new M4 test functions
159 new M4 assertion call sites
146 total _test* functions in the test tree
799 total assertion call sites in the test tree
```

These are authored/source-wired counts, not executed Godot results. External verifier commands:

```bash
godot --version
godot --headless --path . --editor --quit
godot --headless --path . -s res://tests/run_tests.gd
./scripts/verify.sh
```

Acceptance target: Godot 4.7.2 compatible parse, static 0 failures, runtime 0 failures, snapshot PASS, and deterministic 10,000F stress PASS.

## M4 Intentional Non-Goals / Retained Debt

M4 does not add Character 3, Projectile/Zoner runtime, command grabs, air throws, armor, invulnerability, counter hit, parry, stance/install/summon mechanics, box/movement timelines, block pushback, combo/damage scaling, Touch UI, Replay, Round expansion, presentation assets, Character Select, Online, rollback networking, lobby, matchmaking, or ranking.

Known debt intentionally retained: float Rect2/Vector2 gameplay collision, possible float horizontal knockback damping, crouch standing-hurtbox prototype, no formal block pushback, GetUp state-level protection, and no cross-platform determinism audit.

## M5 COMPLETE — Character 3 / Zoner / Projectile Architecture Proof

M5 adds `zone_fighter` and a generic deterministic projectile subsystem while retaining one Fighter/Input/HFSM/MoveRunner/CombatResolver architecture. The formal proof is that the same canonical `SPECIAL_NEUTRAL` resolves as a Generic body strike, a Rush body strike, or a Zone projectile-spawning move solely through each Fighter's MoveRegistry/MoveData.

Key M5 results:

- `ProjectileData` + `ProjectileSpawnData` are immutable configuration; `ProjectileRuntime` + `ProjectileSystem` are battle-owned mutable simulation state.
- Projectile position/facing/lifetime/instance identity are fixed-tick deterministic; no Area2D, engine physics query, delta, Timer, animation callback, or Sprite controls gameplay.
- New projectiles do not move on their spawn frame; hitstop freezes projectile movement/lifetime.
- Projectile contacts use the shared `CombatResolver` and canonical `HitResult.HIT/BLOCK`; guard front/back uses projectile origin, not owner position.
- Detached projectile impacts do not modify the owner's current MoveRunner connection facts.
- Multiple concurrent projectiles, first-hit despawn, owner-HITSTUN persistence, owner-KO cleanup, and battle-reset cleanup are defined.
- Snapshot schema is now v5 and captures projectile serial/entities plus MoveRunner spawn-once bookkeeping; restore rehydrates ProjectileData through owner MoveRegistry/source move/spawn index and validates stable projectile ID.
- BattleStateHasher includes all future-affecting projectile runtime state.
- F1 displays projectile gameplay boxes; F2 reports active projectile runtime state; CombatLogger has sparse projectile lifecycle records.
- Default debug matchup is P1 `zone_fighter` vs P2 `generic_fighter`.

### M5 validation status in this coding environment

Actually executed:

```text
python3 scripts/static_validate.py
→ 1309 passed / 0 failed

./scripts/verify.sh
→ Static 1309 / 0
→ Godot Runtime NOT RUN — executable unavailable
```

Godot headless runtime tests are fully authored and wired but were **not executed** here because neither `godot` nor `godot4` is available. External verification remains required.

M5 source adds 34 `_test*` functions with 230 assertion-call sites across seven new suites. Whole-project inventory after M5 is 180 `_test*` functions and 1029 assertion-call sites. The deterministic 10,000F stress source now covers Generic mirror, Rush mirror, Generic/Rush, and Zone/Generic projectile phases while retaining previous invariants.

### M5 intentional boundary

M5 does not implement projectile clash/reflect/parry/absorb, beams, lasers, zones, traps, homing/arc/gravity projectiles, multi-hit/piercing projectiles, command grabs, CharacterMechanicRuntime, Touch UI, Replay, Online/rollback networking, expanded Round/Character Select, VFX/SFX, projectile sprites, cinematic Ultimate, Box Timeline, or Movement Timeline.


## M6 Current Match / Replay Foundation

- `BattleSimulation` remains the only gameplay tick authority and now owns a small `RoundController`. Global `frame_number` remains monotonic across rounds; only explicit full-match reset returns it to zero.
- Default Versus rules are first-to-2, 5940F timer, 90F post-round, meter reset each round. Training disables the timer/match-over and performs 60F KO auto-reset with zero wins.
- Round result is determined only after all same-frame strike/projectile/throw outcomes apply. KO has priority over timeout; timeout compares post-apply HP.
- Round reset clears Fighter mutable runtime/input history/buffer/MoveRunner/contact state, restores HP/meter/positions/facing, and clears active projectiles while preserving the per-match projectile serial. Full-match reset also resets serial and Fighter attack-instance serials.
- Snapshot schema is **v6** and includes stable MatchRules identity plus all RoundController mutable state. BattleStateHasher hashes the same canonical Match/Round fields.
- Replay foundation records one authoritative normalized P1/P2 `InputFrame` pair for every simulation frame. ReplayData never stores Fighter/Move/Projectile runtime state.
- Replay metadata: schema v1, combat-rules version 1, rules ID, `greybox_stage`, P1/P2 character IDs, seed=0 slot, initial simulation frame, complete frame stream, expected final BattleStateHasher hash.
- `ReplayInputSource` implements the existing InputSource contract with random-access frame lookup. `ReplayCodec` is the only JSON/Dictionary/FileAccess persistence boundary and uses `.tbf_replay.json`.
- F2 exposes rules/round/wins/timers/match winner plus replay recording status; logger adds sparse round/match/replay diagnostics.

### M6 verification status in this coding environment

Godot runtime execution remains **NOT EXECUTED** because `godot` / `godot4` are unavailable. Source/runtime tests are authored and runner-wired. Execute `python3 scripts/static_validate.py`, `./scripts/verify.sh`, and the external Godot 4.7.2 headless commands before claiming runtime PASS.

### M6 intentional boundary

Replay is same-build/same-rules foundation only: no CombatDataHash, cross-build migration, replay seeking/snapshot checkpoints, video replay, Online/rollback prediction, network input, result UI, Round presentation, Training UI, Touch UI, Character 4, Beam/Trap/Summon, or presentation overhaul is implemented.


## M7 COMPLETE — Presentation Foundation

M7 adds a strictly one-way presentation layer over the M6 deterministic simulation. `BattleSimulation` remains gameplay truth; presentation can read authoritative Fighter/Projectile/Round state and consume `CombatEvent`, but it never owns damage, Meter, movement, MoveRunner timing, collision, Round timing, Replay inputs, snapshot state, or state hashing.

Key M7 foundations:

- `CharacterPresentationData` is separate from gameplay `CharacterData` and pairs to it only through the stable character ID. Generic, Rush, and Zone each have presentation resources; they may share the greybox visual scene while resolving different display names and animation keys.
- `FighterPresentationController` maps authoritative HFSM / current Move ID to a replaceable `FighterVisual` adapter. Visual local origin is feet-center. Simulation/render conversion is centralized at **100 simulation units = 1 pixel**. Facing is read from simulation and mirrored visually only.
- Projectile visuals are keyed by deterministic `ProjectileInstanceID`, read `ProjectileRuntime.position_units/facing`, support concurrent projectiles, and disappear when the gameplay entity disappears. No Texture/Sprite state is collision truth.
- The production HUD foundation reads current HP, Meter, timer, Round wins, Round state, Training state, and presentation display names. HUD events never subtract HP or award Meter.
- `RoundPresentationOverlay`, placeholder VFX, audio cue hooks, and camera follow/shake are presentation-only. Their render-time delta/tween/audio lifetimes may differ from simulation without gating gameplay.
- Presentation-significant events now carry scalar provenance needed for deterministic `PresentationEventId`: simulation frame, type, participant IDs, Move ID, attack/projectile instance IDs, and Round facts where relevant. `PresentationEventLedger` deduplicates one-shot feedback without entering BattleSnapshot or BattleStateHasher.
- Restore/resimulation clears pending gameplay-to-presentation event output as before; stateful visuals use `resync_all()` from the latest authoritative simulation. One-shot VFX/audio/camera state is intentionally not restored.
- Headless Round/Projectile/Replay tests remain presentation-free. Snapshot stays **v6** and Replay schema stays **1**. Combat-rules version is **2** because M7 also fixes one proven M6 POST_ROUND deterministic gameplay defect; presentation itself does not require the bump.

### M7 validation status in this coding environment

Source/static validation is executed locally. Godot headless runtime remains **NOT EXECUTED — external verifier required** because neither `godot` nor `godot4` is available. M7 presentation runtime tests are authored and wired into `tests/run_tests.gd`; they must be executed by the external Godot 4.7.2 verifier before Runtime PASS can be claimed.

### M7 intentional boundary

M7 does not add Character 4, official character sprite/audio assets, hitboxes from animation, root motion, animation-driven movement, Beam/Trap/Summon, CharacterMechanicRuntime, Touch UI, Character Select, Main Menu, Result Scene, Online/rollback networking, prediction/confirmation, Replay seek/timeline UI, ranking, or matchmaking.

## M8 — Solo Playtest + Core Charge Combat

M8 turns single-developer playtesting into a first-class development path without creating a second combat authority.

- Startup now opens a development Mode Select with **1P VS CPU** and **2P LOCAL**.
- Local controls are unchanged: P1 `WASD / U I J K L`; P2 `Arrows / M , . / ;`.
- In VS CPU, P1 is human and P2 is a deterministic `CpuInputSource`. P2 keyboard input is not wired to Fighter 2.
- The CPU emits the same normalized InputFrames as a human source. It uses an 8F reaction cadence, fixed deterministic integer variation, spacing/guard/throw/normal/jump/special/ultimate rules, and real press/hold/release edges for Charge Special.
- Replay still records only authoritative InputFrames, so CPU matches replay without rerunning AI decision logic.
- `SPECIAL_NEUTRAL` is now a generic hold/release Charge entry for Generic/Rush/Zone: **1–23F Lv1, 24–53F Lv2, 54F+ Lv3**. Lv3 holds indefinitely until release.
- Charge is grounded, immobile, facing-locked, vulnerable to strike/throw, and cannot walk/jump/dash/guard/normal/throw/Ultimate while committed.
- Heavy -> Special cancel enters CHARGE through existing data-defined cancel windows. Release attacks are ordinary MoveData and retain data-defined Special -> Ultimate routes where configured.
- Generic is a charge strike prototype, Rush is a data-driven forward-moving charge strike, and Zone uses three standard ProjectileData/ProjectileSpawnData levels. M8 adds no Armor subsystem.
- Snapshot schema is **v7** for Charge state. Replay schema remains **v1**; CombatRulesVersion is **v3**.
- Salad Cat remains the `generic_fighter` production presentation, Magic Orange Cat remains `zone_fighter`, and `rush_grappler` remains Greybox.

### M8 verification in this coding environment

`python3 scripts/static_validate.py` is the source-level gate. Godot runtime must still be executed externally when `godot`/`godot4` is unavailable. `scripts/verify.sh` may be invoked with `bash scripts/verify.sh` if an extracted ZIP does not preserve its executable bit.

### M8 deferred mechanics

Armor, Install, Summon, Counter, formal expanded roster, Character Select, Touch UI, Online/rollback networking, lobby/matchmaking/rank/story and final production CPU AI remain outside M8.

## M9P Production Art Pipeline

M9P separates fighter body art from detached world/screen art. Existing Salad Cat and Magic Orange Cat 250-frame body packs remain valid `BASE_FIGHTER` packs. New builders support manifest-driven transformed bodies, arbitrary-aspect projectile/effect/hazard art, and 16:9 Ultimate screen art without changing gameplay geometry.

See `docs/production_art_asset_contract.md` and `docs/art_requirements/`.

Development preview: open `res://presentation/preview/character_preview.tscn` and choose Character → Pack Type → Asset → Animation/Effect. The preview never instantiates gameplay authority.
