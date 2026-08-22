# CONTRIBUTING_AI — M7 Complete Architectural Guardrails

## Non-negotiable Authority Boundaries

1. `BattleSimulation` is the only gameplay tick authority. Presentation may read state / consume output; it may not decide combat.
2. Never let AnimationPlayer, Sprite, HUD, VFX, SFX, Camera, Touch UI, Tween, wall-clock Timer, or render callbacks cause damage, Meter changes, cancels, or move-state transitions.
3. Combat is fixed 60Hz. Meter, Cancel, Special, Ultimate, movement, hitstop, and buffers use simulation frames / integer counters only.
4. Preserve the explicit BattleSimulation ordering. Do not replace combat with signal chains or same-tick recursive re-simulation.
5. `fighter.gd` is a small composition root/orchestrator. Do not move Meter rules, combo routes, CancelWindow evaluation, jump physics, throw geometry, command timing, or snapshot serialization into it.

## Permanent Input Guardrails

6. P1 desktop mapping remains `W/A/S/D + U/I/J/K/L`.
7. Combat Core does not know key letters. `KEY_K` / `KEY_L` are allowed only in physical keyboard input wiring, never in Fighter/StateMachine/MoveRunner/CombatResolver.
8. `InputFrame.InputButton` contains exactly `LIGHT`, `HEAVY`, `GUARD`, `SPECIAL`, `ULTIMATE`.
9. Never add JUMP, CROUCH, THROW, DASH, BACKSTEP, UP/DOWN/FORWARD/BACK to the button bitmask.
10. Jump is derived from direction edges in `InputHistory`; Throw is a HEAVY ActionIntent with request-frame `forward_held`; Dash/Backstep are facing-relative history commands.
11. When multiple action press bits occur in one InputFrame, preserve `ULTIMATE > SPECIAL > HEAVY > LIGHT`. Forward + selected HEAVY must still map to Throw.

## ActionIntent / Buffer Guardrails

12. `ActionIntent` is request-frame context: action button, source frame, direction, facing-at-request, forward/back held.
13. Never reinterpret a buffered intent using consumption-frame keyboard/direction/facing.
14. `InputBuffer` stays one slot / 5 simulation frames / latest intent wins and stores only copied ActionIntent data.
15. InputBuffer must not know MoveData, CancelWindowData, Meter, Node, Resource pointer, Callable, or move-start logic.
16. Guard remains higher-priority behavior. Buffered Special/Ultimate cannot bypass a held Guard state.
17. Forced reactions clear inappropriate offensive buffered intents; no stored wakeup Ultimate.

## Meter Guardrails

18. Meter is Fighter-owned gameplay runtime state implemented by `MeterComponent`, integer range 0..100.
19. HUD/Debug may read Meter but never owns or mutates authoritative Meter policy.
20. Move costs and rewards are data on `MoveData`; never hard-code `if move_id == ...: meter += ...` in Fighter/MoveRunner/CombatResolver.
21. Meter gain comes only from authoritative applied `HitResult` outcomes (HIT/BLOCK/THROW), not box overlap, Animation, VFX, CombatEvent presentation, or audio.
22. Meter cost is checked before move start and spent only on a successful generic move start/cancel. Never start Ultimate and then discover insufficient Meter.
23. Do not refund Ultimate Meter because of whiff, interruption, KO, or presentation state.
24. Duplicate AttackInstance contact protection must naturally prevent duplicate damage and duplicate Meter gain.
25. Same-frame trades retain resolve-both-then-apply-both ordering so both valid attackers receive their outcome rewards.

## MoveData / MoveRunner Guardrails

26. Character differences belong primarily in `MoveData`, `MoveSetData`, `CharacterData`, and typed optional mechanic data such as `CancelWindowData`.
27. Never add fixed CharacterData slots such as `special: MoveData` / `ultimate: MoveData` when MoveSetData already owns the move array.
28. Move IDs are stable StringNames. Never use array position as semantic move identity.
29. MoveRunner is generic. Never branch on STAND_LIGHT / STAND_HEAVY / SPECIAL_NEUTRAL / ULTIMATE or character ID.
30. MoveRunner may understand MoveData timeline, current frame, AttackInstance identity, connection facts, and generic cancel-window queries only.
31. A cancel replaces the running move through the same MoveRegistry -> MoveData -> MoveRunner start semantics, creates a new AttackInstance ID, and begins at the normal frame-1 convention.
32. Never let a canceled old AttackInstance continue producing boxes/hits.
33. Hitstop freezes MoveRunner timeline. Do not make cancel logic advance move frames through hitstop.

## Cancel / Combo Guardrails

34. `CancelWindowData` owns start/end frame, typed condition, and allowed target Move IDs.
35. M3 conditions are only ALWAYS, ON_HIT, ON_BLOCK, ON_HIT_OR_BLOCK unless a future spec explicitly expands them.
36. Meter requirement is the target MoveData cost; do not create a duplicate METER_REQUIRED cancel condition.
37. Combat outcome marks current MoveRunner connection facts after authoritative resolution/application. MoveRunner must never perform Collision itself.
38. InputBuffer must not evaluate cancel windows.
39. Cancel decisions occur in a later normal simulation decision phase after HIT/BLOCK facts exist; never retroactively consume input and rerun collision in the same resolution tail.
40. Preserve the distinction: Link = previous move fully recovered; Cancel = early replacement from data window; M3 Chain = Normal->Normal data-defined Cancel.
41. Do not add extra M3 routes beyond the documented Light->Light, Light->Heavy, Heavy->Special, Special->Ultimate without a new spec.

## State / Existing M2 Guardrails

42. Special and Ultimate are ordinary `GROUNDED/GROUND_ATTACK` MoveData-driven attacks. Do not add SPECIAL_STATE / ULTIMATE_STATE solely for move names.
43. Ground Special/Ultimate cannot force-start from Airborne, Hitstun, Blockstun, THROWN, KNOCKDOWN, GETUP, KO, active Dash/Backstep, or Landing recovery.
44. Air Special/Ultimate are not implemented in M3.
45. Preserve Forward+Heavy Throw, guard matrix, same-frame trades, end-of-tick facing, attack facing lock, integer air integration, and GetUp temporary protection.
46. Do not add block pushback, crouch hurtbox changes, projectile, armor, counter hit, formal invulnerability, bounce systems, or online features as incidental M3 fixes.

## Snapshot / Rollback-Foundation Guardrails

47. Every mutable gameplay field that can change future simulation must be captured, restored, and hashed in explicit canonical order.
48. M4 snapshot schema is version 4. It includes stable immutable `character_id` compatibility identity in addition to Meter, MoveRunner connection facts, serial/AttackInstance/contact/Input/Motor/HFSM/Combatant state.
49. Never snapshot live MoveData/CharacterData/BoxData Resource pointers, Nodes, Sprite/Animation/Audio/VFX/HUD/Camera/Debug Overlay/CombatLogger, Callable, memory address, Node instance ID, or Resource instance ID.
50. Restore current move through stable `current_move_id -> that Fighter's MoveRegistry.get_move()` only after snapshot character identity matches the configured Fighter CharacterData.
51. Preserve complete InputHistory and InputBuffer request-frame context across restore.
52. Preserve current AttackInstance contact registry and next serial so restore cannot duplicate damage/Meter or change cancel identity.
53. Debug-only transient diagnostic fields that cannot affect gameplay decisions do not belong in snapshot/hash; never let such fields become gameplay authority later without adding them.

## Debug / Test Guardrails

54. F1 remains generic gameplay-box rendering; do not add per-move Special/Ultimate debug drawing.
55. F2 may display Meter, connection facts, active cancel window/targets, but debug UI is read-only.
56. CombatLogger remains sparse/debug-only; Meter/cancel logs do not cause gameplay.
57. Every new runtime test must be registered/discoverable from `res://tests/run_tests.gd`.
58. Preserve existing M2 tests; never delete, skip, or weaken an assertion to hide a regression.
59. Stress input must be deterministic/fixed-seed/scripted. M3 stress invariants include Meter bounds, valid move IDs, valid AttackInstance serials, no under-cost Ultimate start, no stuck buffers/states.
60. Missing Godot executable is a verification limitation, not permission to omit implementation/tests. Report runtime as NOT EXECUTED rather than inventing PASS/FAIL.

## M4 Multi-Character Guardrails

61. `CharacterData.id` is the canonical stable character identity. Do not add parallel Resource identity fields such as `character_id`, `fighter_id`, `character_key`, or `character_name_id`.
62. Every Fighter owns a runtime MoveRegistry constructed from its own CharacterData MoveSet. Never introduce a global MoveRegistry where one character can overwrite another character's canonical IDs.
63. Canonical Move IDs are semantic slots. It is valid and expected for two characters' `stand_light` / `ground_throw` / `special_neutral` / `ultimate` to resolve to different MoveData Resources.
64. Ordinary character differences belong in CharacterData, MoveSetData, MoveData, CancelWindowData, movement fields, gameplay boxes, throw data, and Meter fields.
65. Never create `CharacterXXFighter.gd`, `RushGrapplerFighter.gd`, character-ID gameplay switches, or per-character CombatResolver/MovementMotor/InputParser/ThrowSystem code.
66. Battle/scene configuration and tests may reference concrete character Resources; generic combat runtime must not hard-load them.
67. Snapshot restore must reject a character identity mismatch before mutating battle state. Never auto-swap CharacterData during restore.
68. BattleStateHasher must include stable textual character identity; never hash Resource/Node/RID/memory identity.
69. Rush Grappler's stronger throw remains ordinary `GROUND_THROW` data using the shared ThrowSystem and shared throw eligibility matrix. Do not add GrapplerThrowSystem or command-grab exceptions in M4.
70. M4 Rush cancel routes are data-defined: Light F5-11 HIT/BLOCK -> Light/Heavy; Low F8-14 HIT/BLOCK -> Special; Heavy F10-17 HIT/BLOCK -> Special; Special F9-16 HIT -> Ultimate. Generic M3 cancel data must remain unchanged.
71. The default scene may be Generic vs Rush, but architecture/tests must preserve Generic vs Generic, Rush vs Rush, Generic vs Rush, and Rush vs Generic configuration ability.
72. Do not add CharacterManager, RosterManager, CharacterFactory/plugin frameworks, CharacterMechanicRuntime, Projectile, Replay, or Online systems merely because M4 introduces a second data set.
73. Missing Godot remains a verification limitation only: author and wire runtime tests, execute source/static validation, and report Godot Runtime as NOT EXECUTED.

## M4 Scope Boundary

Do not implement Projectile/Zoner Character 3, command-grab subsystem, air throw, armor, invulnerability, counter hit, parry, stance/install/summon mechanics, unique mechanic plugins, box/movement timelines, crouch hurtbox redesign, block pushback, combo/damage scaling, Touch UI, Replay, expanded Round/Training systems, presentation assets, Character Select, Online, rollback networking, lobby, matchmaking, or ranking without a later explicit milestone.

## M5 Projectile / Zone Guardrails — Current Contract

The following M5 rules supersede only older milestone text that described Projectile as a future/non-goal; historical M4 rules remain valid for M4 behavior/regression.

73. Current snapshot schema is **v6**. M4 introduced v4 character identity; M5 introduced v5 projectile state; M6 adds MatchRules/Round state. Do not downgrade current snapshot code.
74. `ProjectileData` / `ProjectileSpawnData` are immutable configuration. Runtime position, owner, instance ID, lifetime, duplicate-contact state, and pending despawn belong only to `ProjectileRuntime` / `ProjectileSystem`.
75. Projectile gameplay is BattleSimulation-owned fixed-tick state. Do not use Area2D, PhysicsBody/CharacterBody, PhysicsServer overlap, `_process`, `_physics_process`, delta, Timer, Tween, Sprite bounds, animation callbacks, or presentation events as gameplay authority.
76. Never create `ZoneFighter.gd`, `ZonerFighter.gd`, `ProjectileFighter.gd`, character-ID projectile branches, a global Projectile singleton, or a duplicate ProjectileCombatResolver.
77. MoveRunner may generically understand `MoveData.projectile_spawns` and spawn-once descriptor bookkeeping; it may not understand `zone_fighter`, `zone_shot`, fireball, or zoner-specific behavior.
78. Projectile collision candidates route through the shared CombatResolver and canonical HitResult HIT/BLOCK path. Do not duplicate the guard matrix, HP mutation, stun, hitstop, knockback, or meter logic in ProjectileSystem.
79. Projectile guard side comes from projectile world attack origin. Never use the owner's current position after spawn to decide projectile front/back.
80. Detached projectile HIT/BLOCK must not set the owner's current MoveRunner `connected_hit` / `connected_block`.
81. ProjectileRuntime position is `Vector2i`, velocity is integer units per simulation tick, facing is captured at spawn, and lifetime is frame-count state. New projectiles do not receive movement/lifetime decrement on the spawn frame.
82. Multiple projectiles per owner are legal unless future explicit data says otherwise. M5 has no projectile limit, clash, hurtbox, pushbox, attack-destruction, piercing, or multi-hit behavior.
83. ProjectileSystem runtime serial and every future-affecting active projectile field are snapshot/hash state. Snapshot structures must never store ProjectileData pointers, Resources, Nodes, RIDs, or memory/instance IDs as compatibility truth.
84. Restore rehydrates ProjectileData only through owner participant → Fighter MoveRegistry → source MoveData → spawn index, then validates stable ProjectileData.id. Invalid identity must reject restore.
85. M5 Zone Fighter keeps the same five InputButtons and desktop key contract. No projectile-specific button/key is allowed.
86. Generic and Rush CharacterData plus their fourteen M4 MoveData Resources are regression-protected. Do not mutate them when adding projectile characters unless a verified architecture defect requires a separately tested fix.
87. CharacterMechanicRuntime remains NOT ADDED. ProjectileSystem is a shared battle subsystem, not a character mechanic plugin.
88. Before extending projectile behavior beyond straight single-hit motion (beam, trap, homing, multi-hit, reflect, summon, etc.), review actual M5 architecture and prove the new generic requirement rather than adding a character branch.


## M6 Match / Replay / Training Guardrails — Current Contract

89. `BattleSimulation` is still the only gameplay tick authority. Round timer/state may never use Timer, delta, wall clock, HUD, scene animation, or CombatEvent callbacks.
90. `RoundController` is a small BattleSimulation-owned deterministic component. Do not add RoundManager/MatchManager/GameFlowManager/SessionManager layers for ordinary lifecycle work.
91. Round result is evaluated only after every same-frame authoritative strike/projectile/throw result applies. Never terminate combat apply on the first KO; preserve double KO and lethal projectile/melee trade.
92. KO has priority over timeout. Timeout decrements integer simulation frames after combat and compares post-apply HP. Gameplay hitstop freezes the round timer.
93. Global BattleSimulation frame is monotonic across rounds. Only explicit full-match reset may reset it to zero.
94. POST_ROUND input is neutralized by simulation authority and no new contacts/spawns are built, but deterministic KO/air/reaction settlement may continue.
95. Round reset clears Fighter runtime/InputHistory/InputBuffer/MoveRunner/contact state and restores canonical position/facing/HP/meter according to MatchRules. Never mutate CharacterData, MoveSet or MoveRegistry during reset.
96. Round cleanup uses `cleanup_temporary_combat_entities()`. Active projectiles clear while the per-match projectile serial remains monotonic; full-match reset resets the serial. Extend this hook later for Beam/Zone/Summon rather than creating a TemporaryEntityManager.
97. Snapshot v6 must capture/restore/hash all RoundController future state and stable MatchRules ID. Replay tooling/presentation state is not snapshot/hash state. Rules mismatch rejects restore; never auto-swap MatchRules.
98. Replay records authoritative normalized `InputFrame` pairs only. Never record raw keyboard keys, ActionIntent, Move IDs, Fighter HP/position, projectiles, animations, presentation events or BattleSnapshots as replay truth.
99. ReplayRecorder observes final consumed InputFrames after Round/Match gating. One pair is required for every authoritative simulation frame; duplicates/gaps/out-of-order frames are invalid.
100. ReplayInputSource implements the common InputSource contract, is random-access by simulation frame, returns copied InputFrames, and must not invoke Fighter/MoveRunner/CombatResolver gameplay methods.
101. Replay metadata is validation, not auto-configuration. Do not load CharacterData/MatchRules from replay IDs or arbitrary `res://` paths. Caller creates the correct Battle first.
102. ReplayCodec is the only replay Dictionary/JSON/FileAccess boundary. Serialize explicit scalar fields only; never `var_to_bytes`, `store_var`, Resource/Node/RID/instance IDs, arbitrary class names, or arbitrary resource paths.
103. Replay schema version and combat rules version are separate. Current prototype values are schema `1`, combat rules `1`, stage `greybox_stage`; replay compatibility is same-build/same-rules only.
104. Preserve the permanent five InputButtons and keyboard mapping. Replay/Training/Round systems add no new action bit/key.
105. Training uses the same BattleSimulation/RoundController with Training MatchRules. Do not add TrainingBattleSimulation/TrainingFighter or gameplay branches by Character ID.
106. Before Online/rollback work, externally execute M6 replay/round/snapshot/stress tests and separately address cross-platform determinism/event-confirmation requirements. M6 replay is an important foundation, not proof of network rollback readiness.


## M7 Presentation Guardrails

- `BattleSimulation` remains the only gameplay truth. Presentation may read getters/state and consume `CombatEvent`; it may never write Fighter/Projectile/Round gameplay state.
- Do not connect `animation_finished`, Tween completion, Audio completion, VFX lifetime, or presentation Timer to MoveRunner actionability, damage, Meter, Round transition, collision, or Fighter state transitions.
- Never derive gameplay collision from Sprite/Texture/Control bounds. F1 gameplay boxes remain authoritative gameplay geometry.
- HUD must not call damage, Meter gain/spend, Fighter reset, Move start, or Round mutation APIs. HUD is a read model/view only.
- Camera viewport/bounds/zoom never define stage collision or gameplay clamp.
- Character-specific visuals belong in `CharacterPresentationData` / visual scenes. Do not add concrete `generic_fighter` / `rush_grappler` / `zone_fighter` branches to generic Fighter/Projectile presentation controllers.
- `CharacterPresentationData` must remain separate from `CharacterData`. Never put SpriteFrames, PackedScene, Texture2D, AudioStream, Material, or VFX scenes into gameplay CharacterData.
- Visual origin convention is feet-center. Convert simulation coordinates only through the centralized 100-units-per-pixel presentation converter.
- Presentation event identity must be derived from deterministic scalar gameplay facts. Never use UUID, Time, random, Node/Resource instance IDs, RID, memory address, or implementation-defined String hash as event identity.
- `PresentationEventLedger`, current visual animation, active VFX, camera shake, overlay timers, projectile visual map, HUD Controls, and Audio players are presentation state: do not snapshot or hash them.
- ReplayData remains normalized InputFrames + metadata/final gameplay hash. Never serialize animation, VFX, Audio, Camera, or presentation resources into ReplayData.
- Presentation may legitimately use `_process(delta)`, Tween, AnimationPlayer, AudioStreamPlayer, lerp, and floating render coordinates because they are non-authoritative. Keep static validation scope-aware: these remain forbidden as gameplay timing authority.
- Full match reset clears presentation ledger/VFX/camera/overlay caches; Round reset resyncs stateful visuals and clears temporary VFX but does not need to erase every prior event ID because event IDs include the monotonic simulation frame.
- Adding a new production character should normally require a gameplay `CharacterData`/MoveSet plus separate `CharacterPresentationData`/FighterVisual scene and bindings, not a CharacterXXFighter gameplay subclass.

## M8 Solo Playtest + Charge Guardrails

107. Match mode may choose InputSource wiring only. `VS_CPU` means Human P1 `KeyboardInputSource` and P2 `CpuInputSource`; `LOCAL_2P` keeps both canonical keyboard sources. Do not branch damage/frame/collision/rules by mode.
108. CPU is an `InputSource`, never a gameplay authority. CPU code must not write Fighter HP/Meter/position, call MoveRunner start/cancel APIs, force HFSM transitions, spawn projectiles, resolve combat, or poll physical keyboard state.
109. CPU decisions must be deterministic from simulation state/frame/participant/fixed seed. No `randf`, `randi`, randomized RNG, wall clock or OS tick source. Replay records the resulting canonical InputFrames, not AI decisions.
110. Preserve the five-button InputFrame contract exactly: LIGHT, HEAVY, GUARD, SPECIAL, ULTIMATE. Throw remains Forward+Heavy; low remains Down+Light; jump and dash/backstep remain direction-history derived.
111. Charge is a generic grounded gameplay state, not a per-character runtime. Never add RushCharge/ZoneCharge/CharacterSpecialSystem or branch on concrete character IDs in FighterStateMachine/MoveRunner/CombatResolver.
112. Charge thresholds and release targets belong to immutable `ChargeSpecialData`. Mutable runtime state stores primitive frame counts and stable IDs only; never snapshot Resource pointers.
113. Special press enters CHARGE. Special hold advances integer simulation frames. Special release selects a release MoveData. Lv3 does not auto-release. Gameplay hitstop freezes charge progress.
114. CHARGE is vulnerable commitment: no movement, dash, backstep, jump, normal attack, throw, guard or Ultimate initiation; no armor/invulnerability. Hit/throw/KO/round reset clears charge.
115. Heavy->Special cancel may enter CHARGE only through an active MoveData cancel window. Interrupt the canceled AttackInstance before charge. Do not keep old hitboxes alive and do not recursively resolve combat in the same tick.
116. Release Lv1/Lv2/Lv3 are normal MoveData. Special->Ultimate permission/cost stays in each target MoveData/CancelWindowData and MeterComponent.
117. Rush charge reward may use generic data fields such as deterministic MoveData travel. Do not add Armor in M8. Zone levels must continue through ProjectileData + ProjectileSpawnData + ProjectileSystem.
118. Snapshot v7 must capture/hash/restore every future-affecting Charge primitive and validate entry Move IDs through the Fighter MoveRegistry. Replay schema stays input-only v1; CombatRulesVersion v3 marks the new gameplay semantics.
119. M8 CPU/Charge tests must remain registered in `tests/run_tests.gd`. Do not delete or weaken prior milestone tests to accommodate M8; update only assumptions that are intentionally versioned by the new Charge entry semantics.

## M9P production art guardrails

- Do not treat a Fighter as one universal sprite sheet. Production art is multi-pack.
- `BASE_FIGHTER` remains the legacy-compatible 250-frame body contract.
- `MODE_FIGHTER`, `WORLD_EFFECT`, `PROJECTILE`, `HAZARD`, `ULTIMATE_SCREEN`, and `ATTACHMENT` are Presentation-only domains.
- Never derive Hitbox/Hurtbox/Pushbox/ProjectileData/MoveData from texture bounds, visual scale, pivot, alpha bounds, or screen coverage.
- Never import `ModePresentationBinding`, `UltimatePresentationBinding`, `EffectPresentationBinding`, `AttachmentPresentationBinding`, `Texture2D`, or `SpriteFrames` from gameplay authority code (`BattleSimulation`, `Fighter`, `CombatResolver`, `MoveRunner`, `ProjectileSystem`, Snapshot/Replay/Hasher).
- Transformation Presentation follows an authoritative gameplay mode id; animation completion never activates gameplay mode.
- Full-screen Ultimate art is screen-space and may never own Gameplay Ultimate freeze/timing.
- Missing Presentation art may fall back to a placeholder; combat must continue.
