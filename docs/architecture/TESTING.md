# Testing Strategy

## Principle

Evidence must match the acceptance criterion and risk. Behavior-changing work
uses test-first development by default; unit tests alone are not sufficient for
all changes. Record every required level as **PASS**, **FAIL**, or **NOT
EXECUTED**. Manual evidence is an exception when automation is not practical,
not a substitute for an available automated check.

## Test taxonomy

| Level | Use when | Typical evidence |
| --- | --- | --- |
| Static / schema | Resources, manifests, `.tres`, metadata, architecture bans, scripts, or configuration change | `static_validate.py`, resource/schema parser, syntax or lint check |
| Unit | Pure deterministic logic, parsers, conditions, calculations, meters, or isolated state transitions change | Focused deterministic test |
| Character / component | One fighter move, mechanic, resource, or presentation binding changes | Focused character/component test plus resource validation |
| Integration | Runtime components cross a boundary: fighter/move runner, simulation/combat, catalog/loading, or later client/server | Boundary test exercising collaborating components |
| Smoke | A viable application flow needs confidence | Boot → load content → select/create fighters → battle → basic moves → round/KO/result without crash |
| Replay / determinism | `BattleSimulation`, snapshots, restore, hashing, or future-affecting gameplay state changes | Replay, restore, hash, and fixed-input regression |
| End-to-end | User flow spans UI and game/result, or later service flows | UI → game → result; later login → matchmaking → match → result |
| Visual regression | UI, presentation, or asset-pipeline output needs stable visual evidence | Approved screenshot/image comparison or human visual review |
| Performance / stress / soak | Long-running simulation, many effects/projectiles, networking/server, or performance-sensitive work changes | Bounded performance, stress, or soak run with environment/output recorded |

Stage A smoke responsibility is to demonstrate the minimum flow above. This
document defines that responsibility; it does not authorize building new
gameplay smoke infrastructure outside an approved task.

## Selecting and sequencing evidence

- **New behavior:** write or update an acceptance-level test first; observe its
  expected RED result, make the smallest implementation, reach GREEN, then
  refactor and run the relevant regression levels.
- **Bug fix:** first add a reproducer/regression test and confirm the defect;
  fix it, pass the regression, then run related regression coverage.
- **Refactor:** establish sufficient regression/characterization coverage before
  editing, then prove behavior remains unchanged.
- **Non-behavioral work:** select schema/parser, script, lint/syntax, smoke,
  integration, or manual evidence appropriate to the artifact. Do not add a
  meaningless unit test solely for TDD compliance.

The task packet's Test Plan declares expected levels and commands. `verify-change`
uses changed paths, the packet, and this document to select targeted evidence;
it always follows with global verification and task-scope validation unless an
explicit packet exception documents otherwise. A later code/config/resource edit
invalidates prior final verification and requires rerunning relevant checks.

## Current commands and limits

`python3 scripts/static_validate.py` is the static project gate. `bash
scripts/verify.sh` runs static validation, Godot import, and the registered
runtime runner. Godot availability is required for a runtime PASS; unavailable
runtime is **NOT EXECUTED** locally and must fail the CI gate rather than create
a false green. Task packets remain the authority for focused commands.
