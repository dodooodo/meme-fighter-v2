# Two Box Fighting — Architecture — M7 Presentation Foundation

## 1. Authority and Fixed Simulation

Gameplay Simulation is authoritative. Presentation may read simulation state and consume `CombatEvent`; Sprite/Animation/HUD/VFX/SFX/Camera never decide damage, state, movement legality, hit detection, throw success, or frame timing.

Combat advances at fixed 60Hz through `BattleSimulation.simulate_frame()`. Rendering may run at any rate. `SimulationClock` converts render delta into whole simulation ticks, while combat movement itself receives no render delta.

Simulation position/velocity are `Vector2i` integer units. `100 units = 1 pixel`. Godot screen Y grows downward, so negative vertical velocity moves upward.

## 2. Canonical Data Flow

```text
Physical Input
  -> InputSource
  -> InputFrame
  -> InputHistory (60F circular)
  -> InputParser / DirectionCommandRecognizer
  -> ActionIntent
  -> InputBuffer (5F)
  -> FighterStateMachine
  -> ActionMoveMap / movement-state command
  -> MoveRegistry
  -> MoveRunner / MovementMotor
  -> Gameplay Boxes
  -> CollisionSystem / ThrowSystem
  -> StrikeContact / ThrowContact
  -> CombatResolver
  -> HitResult
  -> Combatant + HFSM mutation
  -> CombatEvent
  -> Presentation / Debug
```

`Fighter.gd` remains the composition root/orchestrator. Jump physics live in `MovementMotor`; double-tap recognition lives in `DirectionCommandRecognizer`; throw geometry lives in `ThrowSystem`; forced-reaction timers live in `FighterStateMachine`; serialization lives in snapshot codecs.

## 3. Permanent Input Contract

`InputFrame` contains only normalized direction and action buttons:

```text
frame_number

direction_x: -1 / 0 / +1
direction_y: -1 / 0 / +1

InputButton:
LIGHT
HEAVY
GUARD
SPECIAL
ULTIMATE
```

`JUMP`, `CROUCH`, `THROW`, `DASH`, and `BACKSTEP` are deliberately not button bits.

Permanent P1 desktop simulation mapping:

```text
W = Up / Jump
A = World Left
S = Down / Crouch
D = World Right
U = Light
I = Heavy
J = Guard
K = Special
L = Ultimate
```

Derived commands:

```text
Forward + Heavy                -> Ground Throw
Down + Guard                   -> Crouching Guard
Forward -> Neutral -> Forward  -> Dash Forward
Back -> Neutral -> Back        -> Backstep
Air Light / Air Heavy          -> Air Attack
```

Combat Core does not know keyboard letters. Physical mapping ends at `KeyboardInputSource`.

## 4. InputParser, History, and Request-Frame Context

`InputParser.update(frame, facing, history)` derives:

- world-left/world-right held
- facing-relative Forward/Back held
- Up/Down held
- `up_pressed` from current `direction_y > 0` and previous simulation frame `direction_y <= 0`
- action pressed/held/released bits
- facing-relative dash/backstep command edges via `InputHistory`

`ActionIntent` captures request-frame context (`source_frame`, directions, `facing_at_request`, `forward_held`, `back_held`). Consumption later must not reinterpret direction using the consumption frame.

`InputBuffer` is a single-slot latest-intent-wins 5F simulation-frame buffer. It owns a copied `ActionIntent`, not MoveData/Node/input-device objects.

## 5. HFSM

```text
GROUNDED
├─ IDLE
├─ WALK_FORWARD
├─ WALK_BACK
├─ CROUCH
├─ GROUND_ATTACK
├─ GUARD
├─ LANDING
├─ THROW
├─ DASH_FORWARD
└─ BACKSTEP

AIRBORNE
├─ JUMP
└─ AIR_ATTACK

HIT_REACTION
├─ HITSTUN
├─ BLOCKSTUN
├─ THROWN
├─ KNOCKDOWN
└─ GETUP

DEAD
└─ KO
```

`GROUND_ATTACK` remains generic for Stand Light / Stand Heavy / Crouch Low. `AIR_ATTACK` uses one prototype Air Attack MoveData. `THROW` still runs through generic `MoveRunner` using Ground Throw MoveData.

KO has highest forced priority. Hitstop freezes simulation integration/timeline without deleting velocity. Hitstun/Blockstun remain separate.

## 6. Airborne Simulation

Character movement data:

```text
jump_velocity_y_units_per_tick = -1400
gravity_y_units_per_tick2      = 80
max_fall_speed_y_units_per_tick = 1800
air_forward_units_per_tick      = 240
air_back_units_per_tick         = 210
landing_recovery_frames         = 3
```

Grounded movement pins Y to `ground_y_units` and zeroes vertical velocity. Airborne movement performs per-tick integer integration:

```text
sim_position.y += velocity_y
velocity_y = min(velocity_y + gravity, max_fall_speed)
```

Ground contact is independent of stage X clamping. `resolve_ground_contact()` snaps Y exactly to ground and reports `landed_this_frame`; `clamp_x_to_stage()` never forces Y.

### Jump and Same-Frame Jump + Attack

Jump is legal from controllable grounded states and has movement-state priority over a grounded normal/throw. A Light/Heavy pressed on the same frame remains in `InputBuffer`; on the next airborne tick it may start `AIR_ATTACK`.

Air Guard is forbidden. One Air Attack is available per jump; landing resets availability.

### Air Pushbox Policy

If either fighter is physically airborne, fighter-vs-fighter pushbox separation is skipped. This intentionally permits jumping over the opponent. When both fighters are grounded again, normal deterministic pushbox separation resumes.

### Facing / Cross-over Timing

Facing used by input parsing, movement, boxes, and collision is the tick-start facing. After movement/combat/state settlement, `BattleSimulation` performs the facing update once at end-of-tick; that facing is effective on the next simulation tick.

While `GROUND_ATTACK`, `AIR_ATTACK`, or `THROW` has a running MoveRunner, facing is locked so a hitbox/throw box cannot mirror in the middle of the move.

### Hitstop and Air Velocity

Hitstop freezes integration only. It never assigns `velocity_units = Vector2i.ZERO`; vertical jump/launch velocity survives the frozen frames unchanged.

## 7. Air Attack and Vertical Knockback

`air_attack.tres`:

```text
Startup 6F / Active 4F / Recovery 12F
Damage 70
Hitstun 14F / Blockstun 10F
Hitstop attacker 4F / defender 4F
HitLevel HIGH
Knockback X 700
Knockback Y -350
Static hitbox offset (66,-70), size (104,70)
```

Air Light and Air Heavy both route to this one move.

`HitResult.knockback_y_units` is now active gameplay state. `Combatant.knockback_velocity_y_units` is integrated by `MovementMotor` under gravity during airborne Hitstun. A grounded defender can therefore launch when vertical knockback is negative. If hitstun expires in air, HFSM returns to `JUMP`; if it expires on ground, normal grounded settlement resumes.

An airborne KO cannot act but continues deterministic gravity until ground contact, then remains KO.

## 8. Throw Architecture

Ground action mapping:

```text
Down + Light       -> CROUCH_LOW
Light              -> STAND_LIGHT
Forward + Heavy    -> GROUND_THROW
Heavy              -> STAND_HEAVY
```

Air action mapping maps both Light and Heavy to `AIR_ATTACK`; Forward + Heavy in air is therefore not Throw.

Ground Throw data:

```text
Startup 5F / Active 2F / Recovery 18F
Damage 120
Hitstop 4F / 4F
throw_hold_frames = 10
knockdown_frames = 30
causes_knockdown = true
```

`MoveData.throw_box` is optional and independent of `MoveData.hitbox`. Ground Throw has a throw box and no strike hitbox. `ThrowSystem` performs geometry + eligibility only and constructs `ThrowContact`; HP/state mutation is owned by `CombatResolver.apply_throw_result()`.

Throw whiffs still run the entire Ground Throw MoveData. Guard is throwable. Attacks, airborne, Hitstun, Blockstun, THROWN, KNOCKDOWN, GETUP, and KO are not throwable. LANDING is explicitly throwable in this Greybox version.

HIT, BLOCK, and THROW share AttackInstance defender-contact registration so a two-frame active overlap resolves once per defender.

## 9. Dash / Backstep Recognition

`DirectionCommandRecognizer` is stateless and reads `InputHistory` only.

```text
First press -> second press total window <= 12F
Required neutral gap <= 6F
Forward -> Neutral -> Forward = Dash Forward
Back -> Neutral -> Back = Backstep
```

Forward/Back are facing-relative. Holding one direction cannot retrigger a dash because the second directional sample must be a distinct press after neutral.

Character data:

```text
Dash:     8 movement frames @ 900 units/tick, then 4 recovery frames
Backstep: 7 movement frames @ 800 units/tick, then 6 recovery frames
```

No attack-cancel, guard-cancel, run, air dash, or invincible backstep is implemented.

## 10. THROWN / KNOCKDOWN / GETUP

Successful Ground Throw applies damage immediately and enters:

```text
THROWN 10F
  -> KNOCKDOWN 30F
  -> GETUP 18F
  -> Guard / Crouch / Idle according to held input
```

These forced states do not permit movement/attack/guard transitions. InputHistory continues to collect. InputBuffer is cleared on Knockdown/GetUp paths, and wakeup attacks are deliberately disabled in this milestone.

GETUP is not a strike target and not throwable. This is a temporary **Greybox state-level wakeup protection** and is not a formal invulnerability framework.

At GetUp completion:

```text
Guard + Down -> crouching GUARD
Guard        -> standing GUARD
Down         -> CROUCH
otherwise    -> IDLE
```

Horizontal input does not auto-walk at the completion instant, and buffered attacks do not auto-fire.

## 11. Strike / Throw Ordering and Same-Frame Trade

Per tick:

```text
Build A->B StrikeContact
Build B->A StrikeContact
Build A->B ThrowContact
Build B->A ThrowContact

Resolve A->B Strike Result
Resolve B->A Strike Result
Resolve Throw Results

Apply A->B Strike
Apply B->A Strike
Apply Throw Results in stable fighter order
```

Both strike results are resolved before either strike result is applied, preserving same-frame strike trades. `GROUND_ATTACK` is non-throwable, preventing a throw result from being created against an already-attacking target and avoiding throw-vs-strike mutation-order ambiguity in this prototype.

## 12. FrameStepper / Debug

`FrameStepper` is development-only simulation clock control:

```text
F1 boxes
F2 overlay
F3 pause/resume simulation
F4 queue exactly +1 simulation frame
F5 queue exactly +5 simulation frames
```

Render and UI may continue while the battle simulation is paused.

The overlay exposes frame/run status, root/leaf state, facing, integer position/velocity, current move/frame/phase, air-attack availability, HP, stuns/hitstop, guard posture, dash timers, forced-reaction timers, buffered ActionIntent context, and last HitResult type.

`HitboxDebugger` draws hitbox, hurtbox, pushbox, and Throw Range at simulation positions. `CombatLogger` is sparse debug-only transition/event logging and is disabled by default outside debug builds.

## 13. Simulation Stress Test

`tests/stress/test_simulation_stress.gd` runs 10,000 render-free simulation frames with a fixed scripted input pattern. It checks core invariants including state/root legality, sane integer positions, exact grounded Y, eventual landing, HP bounds, KO action lock, MoveRunner bounds, buffer expiry, forced-state exit, dash/backstep exit, and grounded pushbox separation.

No uncontrolled random input is used.

## 14. Complete BattleStateSnapshot

`BattleStateSnapshot` contains all mutable gameplay state required by this milestone to affect future simulation results.

Per battle:

- simulation frame number

Per fighter:

- MovementMotor: simulation position, velocity, facing, landing fact
- Combatant: HP, hitstun, blockstun, hitstop, X/Y knockback velocity, KO, last result
- HFSM: root/state/previous state, GuardPosture, air-attack availability, landing/dash/throw/knockdown/getup and pending timers, jump-start fact
- MoveRunner: stable current move ID, move frame, current AttackInstanceID, next per-fighter instance serial
- HitboxOwner: tracked AttackInstanceID + contacted defender IDs
- InputBuffer: full copied ActionIntent value + expiry frame
- InputHistory: capacity, count, write cursor, and all circular slots / InputFrame values

Static Resource data (`CharacterData`, `MoveData`, `BoxData`, MoveRegistry copies), Nodes, Sprite/Animation/Audio/Camera/HUD/VFX/debug objects, Callables, and signals are not snapshot state.

## 15. Snapshot Dependency Boundaries and Restore

`FighterSnapshotCodec` maps component state to value DTOs. `MoveRunner` stores a stable `current_move_id`; restore calls `MoveRegistry.get_move(id)` rather than retaining a Resource pointer. InputHistory restores the exact circular slot/cursor state. Buffered ActionIntent is reconstructed as a fresh object so restored state cannot alias a mutable pre-restore object.

AttackInstance contacted-defender state is restored so an active move that already contacted a defender cannot damage it again after restore.

`InputParser` has no hidden command timeline state; it is derived again from the restored latest InputFrame/history + facing.

## 16. Event Queue Policy

`CombatEvent` is presentation output. Already-presented/pending presentation events are not part of the snapshot. On successful restore, `BattleSimulation` clears its pending event queue.

Future rollback presentation will need predicted/confirmed event deduplication. That is intentionally not implemented here.

## 17. State Signature / Snapshot Testing

`BattleStateHasher` appends snapshot fields in canonical explicit order (frame, P1, P2, fixed per-fighter fields, circular slots) and hashes the canonical string with SHA-256. It never depends on Dictionary iteration, Node/Resource instance identity, or memory address.

Authored snapshot tests cover:

- F120 capture -> F180 simulate -> restore F120 -> exact replay -> same signature
- Light Active
- Heavy Recovery
- Airborne Jump
- Air Attack
- Blockstun
- Dash
- Throw Active
- THROWN
- KNOCKDOWN
- GETUP
- duplicate active-hit protection after restore
- InputHistory first dash tap across restore
- full buffered ActionIntent context

## 18. Known Determinism Debt

M3 preserves the M2 same-build snapshot/re-simulation foundation and extends its schema for Meter/Cancel runtime state. It still does not claim rollback-grade cross-platform determinism. Known debt intentionally retained:

- gameplay boxes use existing `Rect2` / `Vector2` float geometry
- horizontal knockback damping uses existing float multiplication/rounding
- no full platform/compiler deterministic audit has been performed

These are documented rather than prematurely rewritten in this milestone.


---

## M3. Meter Architecture

Meter is a small Fighter-owned gameplay component:

```text
Fighter
  -> MeterComponent (int 0..100)
```

`MeterComponent` owns only deterministic value operations (`gain`, `can_spend`, `spend`, `reset`, `restore_value`). Rules for a specific move remain data:

```text
MoveData
  meter_cost
  meter_gain_on_hit
  meter_gain_on_block
  meter_gain_on_throw
```

The authoritative reward path is:

```text
StrikeContact / ThrowContact
  -> CombatResolver resolves HitResult
  -> BattleSimulation keeps same-frame resolve-both ordering
  -> CombatResolver applies result
  -> duplicate contact is recorded
  -> current MoveRunner is marked HIT/BLOCK when applicable
  -> attacker MeterComponent receives MoveData reward
```

The reward is not emitted from geometry overlap or presentation. Since reward occurs only after the same duplicate-contact gate as damage/block/throw application, one AttackInstance/defender pair can reward only once.

Move cost is checked before a move begins. The generic state-machine start/cancel path resolves the target MoveData from MoveRegistry, checks `meter.can_spend(move.meter_cost)`, starts the move, then immediately spends the cost. Failed affordability never enters startup. A successful Ultimate start does not refund Meter on later whiff/interruption.

Meter is not CharacterData mutable state and is not HUD state.

## M3. Data-defined Cancel Windows

`CancelWindowData` is a typed Resource containing:

```text
start_frame: int
end_frame: int
condition: ALWAYS | ON_HIT | ON_BLOCK | ON_HIT_OR_BLOCK
allowed_target_move_ids: Array[StringName]
```

`MoveData.cancel_windows` is a typed array of these Resources. This makes routes character/move data rather than individual-move branches in MoveRunner.

`MoveRunner` owns only generic runtime facts needed to query that data:

```text
current move ID / MoveData
move frame
AttackInstance ID
next AttackInstance serial
connected_hit
connected_block
```

CombatResolver marks connection facts only after authoritative result application. MoveRunner does not perform Collision or decide HIT/BLOCK itself.

The decision path on a later simulation input phase is:

```text
InputFrame
 -> InputHistory / InputParser
 -> copied ActionIntent in InputBuffer
 -> FighterStateMachine
 -> ActionMoveMap(ActionIntent request-frame context)
 -> candidate target Move ID
 -> current MoveRunner.can_cancel_to(candidate)
      frame window
      allowed target
      HIT/BLOCK condition
 -> MoveRegistry target lookup
 -> target Meter affordability
 -> MoveRunner.start_cancel(target)
 -> target Meter spend
 -> InputBuffer consume
```

No cancel is triggered from the combat-resolution tail and collision is never recursively rerun in the same tick. Hitstop still freezes MoveRunner timeline.

A successful cancel replaces the old move, resets connection facts, creates a fresh AttackInstance ID/serial, and begins the target using the same frame-1 start convention as a normal move. HitboxOwner is explicitly moved to the new instance identity so the old instance cannot remain authoritative.

Terminology:

- **Link**: old move fully recovers, Fighter becomes normally actionable, next move starts normally.
- **Cancel**: old move is still running and a CancelWindowData permits early replacement.
- **Chain**: M3 treats Normal -> Normal as a data-defined Cancel; no separate ChainSystem exists.

## M3. Prototype Cancel Graph

```text
Stand Light  F6..F12  ON_HIT_OR_BLOCK -> Stand Light
Stand Light  F6..F12  ON_HIT_OR_BLOCK -> Stand Heavy
Stand Heavy F12..F20  ON_HIT_OR_BLOCK -> Special Neutral
Special     F11..F18  ON_HIT          -> Ultimate
```

The Ultimate target still independently requires 100 Meter. Crouch Low, Air Attack, Ground Throw, and Ultimate do not gain M3 cancel routes.

## M3. Special and Ultimate as Ordinary MoveData

Special and Ultimate do not create new HFSM leaf states. Both are grounded attacks using the existing:

```text
GROUNDED
  -> GROUND_ATTACK
```

They enter through the same normalized input and generic move-start path as other attacks:

```text
InputButton.SPECIAL  -> ActionMoveMap -> &"special_neutral"
InputButton.ULTIMATE -> ActionMoveMap -> &"ultimate"
```

Air ActionMoveMap intentionally maps neither SPECIAL nor ULTIMATE. Physical `KEY_K`/`KEY_L` stay in the keyboard adapter and never enter generic combat code.

The move resources carry startup/active/recovery, combat values, boxes, Meter data, and cancel windows. CombatResolver does not branch on move name or character ID.

## M3. Simultaneous Action Priority

`InputParser.action_pressed_intent()` resolves pressed action bits deterministically:

```text
ULTIMATE > SPECIAL > HEAVY > LIGHT
```

The resulting ActionIntent still snapshots source-frame direction/facing. If HEAVY is selected, `ActionMoveMap` retains Forward+Heavy -> Ground Throw precedence. Guard remains state-priority behavior and cannot be bypassed by a buffered Special/Ultimate while held.

## M3. Snapshot / Restore / Hash — Schema Version 3

M3 changes future simulation outcome through two new categories of mutable state, both serialized:

```text
Fighter Meter value
MoveRunner connected_hit
MoveRunner connected_block
```

Existing state remains captured, including current move stable ID/frame, AttackInstance ID, next serial, contact registry, MovementMotor, Combatant, HFSM/timers, InputBuffer ActionIntent, and full InputHistory circular history.

Restore does not retain a MoveData pointer:

```text
snapshot.current_move_id
 -> MoveRegistry.get_move(current_move_id)
 -> restore MoveRunner frame / instance / serial / connection facts
```

`BattleStateHasher` adds Meter and connection booleans in explicit fixed canonical order. It does not use Dictionary iteration order, memory address, Node IDs, or Resource instance IDs.

Already-presented events, Debug Overlay, CombatLogger, Sprite/Animation/Audio/VFX/Camera/HUD remain outside gameplay snapshot state.

## M3. Character Scalability Boundary

A second ordinary grounded strike Special with different frame data/box/Meter/cancel graph should require new/changed Resources in the character MoveSet, not copies of Fighter or edits to CombatResolver, MovementMotor, CollisionSystem, ThrowSystem, InputFrame, or InputBuffer.

A genuinely new mechanic category (for example a future Projectile subsystem) may require a new generic runtime subsystem, but must not be implemented as character-ID branching.

## M3. Debug / Verification Boundary

F1 remains generic box rendering; Special/Ultimate boxes appear because they are ordinary active MoveData hitboxes.

F2 reads Fighter state and now exposes Meter, current move connection result, active cancel-window state, and allowed cancel targets. CombatLogger adds sparse Meter/cancel diagnostics but is not snapshot state and never causes gameplay.

The implementation package includes M3 runtime/snapshot/stress tests registered in `tests/run_tests.gd`, plus source architecture checks in `scripts/static_validate.py`. In the implementation environment, Godot is unavailable, so runtime execution is deliberately left to an external Godot-capable verifier rather than being inferred from source checks.

# M4 COMPLETE — Second Character Framework Validation

## M4 Character Configuration Contract

M4 proves two different close-range characters through one gameplay runtime. `CharacterData.id` is the existing canonical stable character identity; no parallel `character_id` / `fighter_id` Resource field was added. CharacterData and MoveData are immutable configuration Resources. Runtime HP, Meter, InputHistory, InputBuffer, HFSM state, MoveRunner state, Combatant state, and contact history remain per-Fighter objects.

The default development match is configured by `battle_scene.tscn` as:

```text
P1 = generic_fighter
P2 = rush_grappler
```

`BattleScene` owns those two CharacterData assignments and passes them into `BattleSimulation.configure()`. Generic combat code does not load a concrete character Resource.

## M4 Per-Fighter Move Registry

Every Fighter constructs its own `MoveRegistry` from `fighter.data.move_set` during configuration. Canonical Move IDs identify semantic move slots, not globally unique MoveData Resources.

```text
P1 generic_fighter registry
  stand_light -> Generic Stand Light (50 damage, 5/3/10)

P2 rush_grappler registry
  stand_light -> Rush Stand Light (45 damage, 4/3/9)
```

This is intentional. `MoveRunner`, `CombatResolver`, `ThrowSystem`, and snapshot restore always resolve a Move ID through the owning Fighter's registry. No global registry overwrite exists.

## M4 Rush Grappler Data-Only Identity

`rush_grappler` uses the same Fighter, HFSM, MovementMotor, MoveRunner, CombatResolver, CollisionSystem, ThrowSystem, MeterComponent, Input parser/buffer, and snapshot codecs as `generic_fighter`. Its identity comes from data only:

- faster ground/air movement and dash/backstep values in CharacterData;
- seven independent MoveData Resources under `data/moves/rush_grappler/`;
- stronger/larger Ground Throw data using the existing ThrowSystem;
- distinct Meter rewards and cancel windows;
- the same canonical IDs: stand_light, stand_heavy, crouch_low, air_attack, ground_throw, special_neutral, ultimate.

No `RushGrapplerFighter.gd`, CharacterManager, CharacterFactory, Projectile subsystem, or CharacterMechanicRuntime was added.

## M4 Snapshot / Restore / Hash — Schema Version 4

Once multiple characters can share the same `current_move_id`, a move ID alone is insufficient compatibility identity. `FighterStateSnapshot` therefore stores:

```text
fighter_id     # runtime slot identity
character_id   # immutable CharacterData.id compatibility identity
current_move_id
```

Capture stores `fighter.data.id`. Restore first checks that the snapshot character ID equals the already-configured Fighter CharacterData ID. A mismatch is rejected; restore never swaps CharacterData or silently resolves the move through the wrong registry. Battle-level restore preflights both participants before mutating either Fighter.

On a compatible restore:

```text
snapshot.current_move_id
 -> that Fighter's MoveRegistry.get_move(current_move_id)
 -> correct character-specific MoveData
```

`BattleStateHasher` includes the textual stable character ID in canonical order. Resource instance IDs, Node IDs, RIDs, and memory addresses are never used.

## M4 Scalability Boundary

M4 proves that another ordinary close-range character can be added primarily with CharacterData + MoveSetData + MoveData + CancelWindowData and scene/test configuration. It does not prove projectile, summon, stance/install, or other unique-mechanic architectures. Those require separate generic subsystem milestones rather than character-ID branches.

# M5 COMPLETE — Character 3 / Deterministic Projectile Architecture Proof

## M5 Battle-Owned Projectile Contract

M5 adds straight, single-hit projectiles as **battle-level mutable gameplay entities**, not Fighter children, Nodes, sprites, engine physics bodies, animation callbacks, or timers. `ProjectileData` and `ProjectileSpawnData` are immutable Resources. `ProjectileRuntime` is small mutable deterministic state. `BattleSimulation` owns one `ProjectileSystem` and is the only gameplay tick authority.

The data flow is:

```
InputFrame
→ ActionIntent / canonical SPECIAL_NEUTRAL or ULTIMATE
→ per-Fighter MoveRegistry
→ MoveData.projectile_spawns
→ MoveRunner move_frame + spawn-once descriptor bookkeeping
→ BattleSimulation spawn request phase
→ ProjectileSystem / ProjectileRuntime
→ ProjectileContact
→ shared CombatResolver
→ HitResult.HIT / BLOCK
→ HP / stun / hitstop / knockback / owner meter
```

Generic and Rush `SPECIAL_NEUTRAL` remain body strikes with empty projectile-spawn arrays. Zone `SPECIAL_NEUTRAL` uses the same canonical Move ID but has no body hitbox and owns one F15 `zone_shot` descriptor. This is intentionally data-driven; MoveRunner, InputParser, and CombatResolver do not branch on `zone_fighter`.

## Projectile Tick Ordering

A normal simulation tick follows this deterministic order:

1. ingest InputFrames;
2. Fighter HFSM/action decisions and MoveRunner starts/cancels;
3. Fighter movement and pushbox resolution;
4. advance projectiles that existed before this tick, unless gameplay hitstop freezes the timeline;
5. consume data-defined projectile spawn descriptors and spawn new entities; newly spawned projectiles do not receive an extra movement/lifetime step;
6. build both Fighter strike contacts;
7. build Projectile contacts;
8. build existing Throw contacts;
9. resolve every strike/projectile/throw result from the same pre-apply state;
10. apply Fighter strikes, then projectile results in deterministic instance order, then Throws;
11. mark HIT/BLOCK projectiles for despawn and perform lifetime/owner-KO cleanup only after apply;
12. finalize Fighter MoveRunner/status/reaction state;
13. update Fighter facing once at end of tick.

This preserves the existing build → resolve → apply same-frame trade contract. A valid projectile result is not cancelled merely because its owner is KO'd by another contact during the same apply phase.

## Projectile Runtime / Lifetime

`ProjectileRuntime.position_units` is `Vector2i`; X movement is `velocity_x_units_per_tick * facing`, with no delta. Facing is captured from simulation facing at spawn and is never re-read from the owner. Y is constant in M5. Runtime instance IDs come from `ProjectileSystem.next_projectile_instance_serial`, beginning at 1 and captured/restored/hashed.

Lifetime convention: a fresh projectile starts with its configured lifetime and receives **no decrement on its spawn tick**. On each later non-hitstop simulation tick it moves once, then decrements once. It remains collision-eligible for that final movement step and is removed at end-of-tick when remaining lifetime reaches zero. Screen/camera bounds never affect gameplay lifetime.

Multiple concurrent projectiles from the same owner are legal. Projectiles have no pushbox/hurtbox, do not collide with each other, cannot be destroyed by normal attacks, cannot hit their owner, and despawn after their first authoritative HIT or BLOCK.

## Shared Combat / Guard Provenance

Projectile geometry is built by `ProjectileSystem`, but damage, guard, stun, hitstop, knockback, and meter authority remain in the shared `CombatResolver`. `ProjectileContact` extends the existing strike provenance shape and supplies its own world incoming side. For projectiles, front/back is determined from **projectile world origin versus defender simulation position**, never the owner's current position. This remains correct after the owner crosses the defender.

Detached projectile HIT/BLOCK does not call `MoveRunner.mark_connected_hit/block`; a projectile may outlive its source move and must not accidentally enable a cancel on whatever move the owner is currently performing.

## M5 Zone Fighter

`zone_fighter` is the third prototype CharacterData and uses the same Fighter, HFSM, MovementMotor, MoveRunner, Combatant, MeterComponent, MoveRegistry, HitboxOwner, InputBuffer, and InputParser. It adds no character-specific runtime class. Its seven moves use the existing canonical IDs. Only Zone Special and Ultimate contain projectile descriptors.

## Snapshot / Restore / Hash — Schema Version 5

M5 bumps same-build snapshot schema from v4 to v5. `BattleStateSnapshot` now captures:

- `next_projectile_instance_serial`;
- an ordered `Array[ProjectileSnapshot]` for all active projectiles.

Each projectile snapshot is resource-free value state: instance ID, owner participant ID, source Move ID, spawn index, ProjectileData textual ID, `Vector2i` position, facing, remaining lifetime, duplicate-contact IDs, pending despawn state, and reason. `MoveRunner` additionally snapshots the projectile descriptor indices already emitted by the current move, preventing duplicate spawns around hitstop/restore boundaries.

Restore preflights projectile identity before runtime mutation. Static data is rehydrated through:

```
owner participant
→ owner Fighter
→ owner MoveRegistry
→ source_move_id
→ MoveData.projectile_spawns[spawn_index]
→ ProjectileData
→ validate ProjectileData.id == snapshot.projectile_id
```

Invalid owner/source/spawn/projectile identity rejects restore rather than silently selecting another Resource. `BattleStateHasher` includes the next serial and every future-affecting projectile snapshot field in deterministic array/instance order; it never hashes Resource instance IDs, Node IDs, RID, pointers, or dictionary iteration order.

## M5 Debug Boundary

F1 draws projectile gameplay Rect2 directly from `ProjectileRuntime.gameplay_rect()`, the same geometry source used for collision. F2 shows active projectile count and compact runtime identity/position/facing/lifetime rows. CombatLogger emits sparse spawn/impact/despawn lifecycle records only. None of these systems are gameplay authority.

## M5 Scalability Boundary

M5 proves a fourth ordinary close-range character can remain data-first, and a fourth **straight-line single-hit projectile** character can primarily use CharacterData + MoveSetData + MoveData + ProjectileData/ProjectileSpawnData without character-ID gameplay branches. M5 does **not** prove Beam, Zone/Trap, Homing/Arc/Gravity projectile, multi-hit/piercing, projectile clash/reflect/absorb, Summon, Stance/Install, or other unique mechanic runtime architectures.


## M6 Match Lifecycle Authority

`BattleSimulation` remains the sole gameplay tick authority and owns one small `RoundController`. `MatchRulesData` is immutable configuration; `RoundController` owns only mutable round/match counters, timers, result and participant winner. No Timer Node, delta, wall clock, HUD, CombatEvent, Replay component, or character ID decides lifecycle state.

Authoritative active-tick ordering is: normalized/gated InputFrames → Fighter decisions/movement → existing projectiles advance → data-driven projectile spawns → build all melee/projectile/throw contacts → resolve all outcomes → apply all outcomes/meter → projectile end-of-tick lifecycle → KO/timeout Round evaluation → temporary-entity cleanup → Fighter settlement → facing update. This preserves same-frame trade and double-KO semantics. KO is evaluated before timer timeout; timeout uses post-apply HP. Gameplay hitstop freezes the integer round timer using the same tick-start freeze fact as projectile timelines.

Round states are `ROUND_ACTIVE`, `POST_ROUND`, `MATCH_OVER`. The round-ending tick enters `POST_ROUND` with the full post-round count and builds no further combat on later post-round ticks. Post-round neutralizes player input at BattleSimulation authority while allowing necessary KO/air/reaction settlement. On reset, Fighter mutable runtime/input state is cleared and canonical positions/facings/HP/meter restored. CharacterData/MoveSet/MoveRegistry identities are untouched. Active projectiles clear at round end/reset while `next_projectile_instance_serial` remains monotonic inside one Match; only full-match reset returns it to the initial serial.

Global `BattleSimulation.frame_number` never resets between rounds. `MATCH_OVER` continues incrementing this global frame while gameplay stays frozen. Explicit full-match reset alone returns the frame, score, round state, Fighters, inputs and projectile serial to initial state.

## M6 Snapshot / Hash Extension

Snapshot schema is v6. `RoundStateSnapshot` stores only value state: stable MatchRules ID, round state/number, P1/P2 wins, round timer, post-round timer, round result, pending Match winner and final Match winner. Restore rejects a rules-ID mismatch before mutation. Replay tooling and presentation queues are not gameplay snapshot state; pending presentation events are cleared after restore.

`BattleStateHasher` canonical root order is schema/frame → Round/Match state → P1 Fighter → P2 Fighter → ProjectileSystem. MatchRules ID and every future-affecting RoundController field are hashed. ReplayRecorder/InputSource/file path/playback status are intentionally excluded because they do not affect simulation future state.

## M6 Replay Boundary

Replay is an **input reconstruction** mechanism, not a gameplay-state recording. `ReplayRecorder` observes the final authoritative normalized InputFrames after Round/Match input gating and before Fighter gameplay consumption. It records exactly one continuous P1/P2 pair per simulation frame, including neutral post-round/match-over frames. It never reads keyboard letters, HP, positions, MoveData, ActionIntent or projectiles.

`ReplayData` contains schema/rules/stage/character metadata, a complete ordered `Array[ReplayFramePair]`, and the expected final `BattleStateHasher` String. `ReplayInputSource` is random-access by authoritative frame number and implements the same `InputSource` abstraction used by keyboard input. Playback is caller-configured: metadata validates already-configured CharacterData/MatchRules; replay never auto-loads resources by ID/path.

`ReplayCodec` is the sole serialization boundary permitted to use Dictionary/Array/JSON/FileAccess. It explicitly serializes scalar InputFrame fields (`frame_number`, directions, held/pressed/released bits), validates continuous ordering, direction domains and the five-button bitmask, and rejects incompatible schema/combat-rules/stage metadata. The prototype file extension is `.tbf_replay.json`. No arbitrary class instantiation or `res://` load path is accepted from replay data.

M6 replay compatibility is same-build/same-rules only. Cross-build migration, CombatDataHash/roster manifests, rollback-confirmed recording, replay seek checkpoints and Online transport are deferred.


## M7 Presentation Boundary

### One-way dependency

The permanent direction is:

```text
BattleSimulation authoritative gameplay state / CombatEvent output
    ↓ read-only
BattlePresentationController
    ↓
Fighter visuals / Projectile visuals / HUD / Round overlay / VFX / Audio / Camera
```

Gameplay core never imports or owns `CharacterPresentationData`, `FighterPresentationController`, HUD, Camera, VFX, or Audio. A headless `BattleSimulation.new()` therefore remains sufficient for combat, Round, Projectile, Snapshot, Replay, and stress execution.

### Character gameplay vs visual configuration

`CharacterData` stays immutable gameplay configuration. `CharacterPresentationData` is a presentation-only typed Resource containing stable `character_id`, display name, optional visual scene/offset/scale, state bindings, move bindings, and projectile visual bindings. BattleScene validates `CharacterData.id == CharacterPresentationData.character_id`; the simulation itself does not require presentation resources.

Move visuals resolve by canonical Move ID through the character's presentation binding, so the same `SPECIAL_NEUTRAL` can display different Generic/Rush/Zone animation keys without a character branch in MoveRunner or the visual resolver. Missing bindings fall back to generic placeholder animation instead of affecting gameplay.

### Render coordinates and anchors

`SimulationRenderConverter` is the single conversion contract:

```text
100 simulation units = 1 render pixel
```

Fighter visual local origin is **feet center**. Visual position derives from `Fighter.sim_position`; projectile position derives from `ProjectileRuntime.position_units`. Facing is read from the authoritative runtime and mirrored only in the visual adapter. Visual scale/offset never resizes gameplay boxes.

### Stateful presentation vs one-shot cues

HUD, Fighter visual state, Projectile visual maps, camera follow, and base Round overlay state are rebuilt from current authoritative simulation through `resync_all()`. One-shot HIT/BLOCK/THROW/KO/round VFX, audio, and camera feedback consume `CombatEvent` instead.

`PresentationEventId` derives a canonical textual ID only from deterministic facts (simulation frame, event type, participants, Move ID, attack/projectile runtime identity, and Round facts). `PresentationEventLedger` prevents duplicate one-shot feedback during accidental repeated dispatch and provides a future rollback reconciliation seam. The ledger is presentation runtime state and is **not** captured, restored, or hashed.

Snapshot restore keeps the M6 rule that pending presentation events are cleared. A later identical resimulation recreates identical deterministic event IDs. Fresh Replay playback clears presentation caches/ledger and receives the same simulation event stream through the normal gameplay path.

### Versioning impact

M7 adds no gameplay future-affecting state:

```text
Battle Snapshot version: 6 (unchanged)
BattleStateHasher gameplay fields: unchanged by Presentation
Replay schema: 1 (unchanged)
Combat rules version: 2 (M6 POST_ROUND deterministic defect fix; not caused by Presentation)
```

No presentation Resource, visual transform, animation key, VFX, audio, camera state, or event ledger may enter BattleSnapshot, BattleStateHasher, or ReplayData gameplay truth.

## M8 Solo Playtest / Charge Boundary

M8 keeps the deterministic gameplay graph intact and adds two narrowly scoped authorities.

### M8A — Match Mode and CPU Input

`ModeSelectScene` chooses only the input wiring mode: `LOCAL_2P` or `VS_CPU`. `BattleInputWiring` preserves the canonical desktop mappings and returns `KeyboardInputSource` for both participants in local mode or `CpuInputSource` for P2 in CPU mode. Match mode does not alter damage, frame data, collision, meter, round rules, or character resources.

`CpuInputSource` is a deterministic rules-based playtest bot, not a Fighter controller and not final production AI. Its only gameplay-facing output is the same normalized `InputFrame` consumed by human input. The authoritative path is therefore:

`CPU policy -> CpuInputSource -> InputFrame -> Fighter.ingest_input -> InputHistory -> InputParser -> InputBuffer -> FighterStateMachine -> MoveRunner -> BattleSimulation -> CombatResolver`.

The CPU may read already-established simulation state for distance, move phase, guard state and meter affordability. It may not write HP, Meter, position, state, MoveRunner, ProjectileSystem or CombatResolver. New decisions are reaction-limited at an 8F cadence and variation comes only from a fixed deterministic integer mix of simulation-frame block, participant ID and seed. Replay never stores CPU decisions; `ReplayRecorder` records only the final normalized P1/P2 `InputFrame` stream.

### M8B — Generic Charge Special

Charge is authoritative gameplay state owned by `FighterStateMachine.State.CHARGE`. `MoveData.charge_special_data` points to immutable `ChargeSpecialData`, which defines 24F / 54F thresholds and stable release Move IDs. Runtime mutable charge state is only primitive/ID data: charge frame count, entry move ID and locked facing.

Pressing a legal grounded `SPECIAL_NEUTRAL` that has charge configuration enters CHARGE instead of starting a MoveRunner attack. The press frame counts as Charge F1. Continued held Special advances the integer count on non-hitstop gameplay ticks. Releasing selects `special_neutral`, `special_neutral_l2`, or `special_neutral_l3` through the Fighter's existing `MoveRegistry`. Lv3 never auto-releases.

CHARGE is grounded, immobile, facing-locked, normally strikeable and throwable. It does not grant guard, armor or invulnerability and rejects walk/dash/backstep/jump/Light/Heavy/Throw/Guard/Ultimate while held. Hit/throw/KO/reset clears charge state. Gameplay hitstop freezes the charge count because it freezes the shared authoritative gameplay timeline.

Heavy -> Special cancel remains data-driven. If the current MoveData cancel window permits `SPECIAL_NEUTRAL`, the old AttackInstance is interrupted and the fighter enters CHARGE; no Special hitbox exists until release starts the selected target MoveData. Special-release -> Ultimate remains defined by each release MoveData's own CancelWindowData, never by a Fighter hardcode.

Generic, Rush and Zone share this exact runtime. Their differences live only in MoveData / ProjectileData. Rush release moves use the generic deterministic ground-travel fields on MoveData; Zone release levels use normal ProjectileSpawnData/ProjectileSystem descriptors. No character-ID branch was added to the gameplay core.

### M8 Snapshot / Replay Compatibility

Battle snapshot schema is **v7** because CHARGE adds future-affecting gameplay state. Fighter snapshots store only primitive charge fields/stable IDs, and restore resolves configuration through the Fighter MoveRegistry. BattleStateHasher includes the same charge state in canonical order.

Replay schema remains **v1** because the recorded payload is still normalized InputFrames only. Combat-rules compatibility is **v3** because identical old input streams now have new Charge Special semantics. No Presentation state, CPU decision state, Charge level, or Resource pointer is serialized into ReplayData.

---

# M9P — Multi-Pack Production Presentation Pipeline

## PRODUCTION ART IS MULTI-PACK

A fighter is not represented by one universal sprite sheet.

**Gameplay Entity and Presentation Asset are separate concepts.** A single move may render simultaneously as Fighter Body Animation + Attached Effect + Detached Projectile + World Hazard + Screen Overlay, but only Gameplay Simulation decides combat.

Presentation domains:

1. `BASE_FIGHTER` — normal body pack using either the backward-compatible
   10×5×5 / 250-frame grid or an explicit manifest-driven action-folder source.
2. `MODE_FIGHTER` — manifest-driven complete alternate body such as SUPER_DOGE / TRUE_FACE; frame count and texture aspect ratio are unrestricted.
3. `WORLD_EFFECT` / `PROJECTILE` / `HAZARD` — arbitrary-aspect detached world art.
4. `ULTIMATE_SCREEN` — CanvasLayer/Control screen-space 16:9 art, canonical runtime 1280×720.
5. `ATTACHMENT` — socket-based weapon/item presentation.

`CharacterPresentationData` remains the per-gameplay-character visual bundle and now owns typed mode/effect/ultimate/attachment bindings. Gameplay Resources do not reference these types.

`FighterPresentationController.apply_authoritative_mode_id()` is a one-way Presentation handoff API. M9P does not add gameplay mode state. When a future gameplay mode system owns an authoritative mode id, Presentation may read that id and swap only the FighterVisual child while preserving gameplay Fighter identity, position and state.

`WorldEffectPresenter`, `ProjectileVisualPresenter` and `UltimateScreenPresenter` consume read-only gameplay IDs/events/entities. They cannot define collision, damage, meter, move timing, projectile speed/lifetime, mode duration, simulation freeze, Snapshot fields, Replay identity or hash state.

The canonical production art contract is `docs/production_art_asset_contract.md`.
