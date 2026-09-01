# MEME FIGHTER V2 — Gate 1 Validation Report

## Gate

Objective: preserve the current WIP Canonical Combat foundation and make `python3 scripts/static_validate.py` internally consistent with the current authoritative rules until it reports zero failures.

This gate did not perform CPU tuning, telemetry expansion, final asset binding, matchup work, roster redesign, or final Combat Complete packaging.

## Baseline

Command:

```bash
python3 scripts/static_validate.py
```

Result from the uploaded WIP baseline:

```text
Static validation: 4337 passed, 11 failed
```

## Failure Classification and Repair

### A. Stale expectations — 9

1. `Ground Attack is not throwable`
   - Historical expectation removed.
   - Current invariant: grounded `GROUND_ATTACK` can enter throw-candidate eligibility; an already-active strike wins through `SameTickArbitrator`.

2. `Dash/Backstep recognition uses InputHistory with 12F/6F leniency`
   - Updated to the Canonical 12F total / 4F neutral window.
   - Distinct-tap protection remains validated.

3. `M8 Snapshot schema is v8 for authoritative Charge state while retaining prior state`
   - Replaced by one current schema invariant: `BattleStateSnapshot.VERSION == 9`.

4. `Battle snapshot v8 retains M5 projectile serial and active entity snapshots`
   - Historical version number removed from the requirement.
   - Projectile serial/entity snapshot retention remains validated.

5. `M6 versus_match_rules exact field: round_timer_frames = 5940`
   - Updated to Canonical `round_timer_frames = 3600`.

6. `M8 Battle snapshot schema v8 retains typed RoundStateSnapshot`
   - Historical version number removed.
   - Typed `RoundStateSnapshot` retention remains validated.

7. `Replay format centralizes unchanged schema and M8 combat-rules compatibility constants`
   - Current invariant is `SCHEMA_VERSION = 1`, `COMBAT_RULES_VERSION = 5`.

8. `M8 bumps gameplay Snapshot schema to v7 only for new authoritative Charge state`
   - Replaced with behavior retention checks for Charge and deterministic early-release state across snapshot/capture/restore/hash.

9. `M8 keeps Replay input schema at 1 and bumps combat-rules compatibility to 4 for Charge gameplay semantics`
   - Historical v4 requirement removed.
   - Replay remains normalized-input-only and does not serialize derived gameplay state.

### B. Stale source-shape checks — 2

1. `StateMachine captures prioritized parsed ActionIntent into InputBuffer`
   - Old validator required the obsolete literal `input_buffer.buffer_intent(intent)`.
   - New validator checks the contextual path: parsed `ActionIntent`, 5F normal buffer, 8F wakeup buffer, and `buffer_intent(intent, window_frames)`.

2. `Projectile contact/KO/lifetime cleanup occurs after outcome apply phase`
   - Old validator compared global source-text positions using `str.find()`, which confused helper-definition location with runtime call order.
   - New validator extracts `_simulate_round_active_tick()` and verifies strike/throw application occurs before `projectile_system.cleanup_end_of_tick()` inside the authoritative tick body.

### C. Real implementation regressions — 0

No production gameplay regression was required to be reverted or patched to make the 11 original failures pass.

The current Throw/Snapshot foundation was statically inspected and additional current-invariant checks were added for:

- ±3F Forward+Heavy tolerant recognition.
- Ground Attack throw-candidate eligibility.
- Same-tick active Strike vs Throw arbitration.
- Normal Throw-only 7F pending tech path.
- Command Grab / Capture throw bypass of Normal Throw tech.
- Capture tick counted as tech frame 1 (`expires_frame = frame + 6`).
- Settlement through `resolve_confirmed_throw()` without re-running range/geometry checks.
- Pending Throw storage using stable primitive IDs/data rather than Fighter/Resource/Node pointers.
- Throw Tech emitting `THROW_TECH` without damage, knockdown, or meter application.
- Normal Throw vs Normal Throw Auto Tech.
- Same-frame strike/projectile/throw result application before KO/timeout evaluation.
- Snapshot/capture/restore/hash consistency for throw protection, pending knockdown, throw-tech state, jump buffer expiry, charge early release, combo state, input-buffer expiry, and battle-level pending Normal Throws.

## Current Canonical Versions

```text
BattleStateSnapshot.VERSION = 9
Replay SCHEMA_VERSION = 1
Replay COMBAT_RULES_VERSION = 5
```

## Final Validation

Command:

```bash
python3 scripts/static_validate.py
```

Final result:

```text
Static validation: 4368 passed, 0 failed
```

Additional available non-Godot checks:

```text
python3 -m py_compile scripts/static_validate.py: PASS
bash -n scripts/verify.sh: PASS
bash -n scripts/*.sh: PASS
python3 scripts/validate_task.py --task docs/tasks/active/A-COMBAT-001.md --no-diff: PASS
```

## Godot Runtime

Godot discovery commands were attempted:

```bash
which godot
which godot4
godot --version
godot4 --version
```

Result:

```text
Godot Runtime: NOT EXECUTED
Reason: no godot/godot4 executable is available in this environment.
```

## Files Changed in Gate 1

```text
scripts/static_validate.py
GATE1_VALIDATION_REPORT.md
```

Production gameplay files were not reverted or retuned during this recovery gate.
