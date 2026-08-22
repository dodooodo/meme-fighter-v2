---
id: A-RUN-004
stage: A
type: verification
status: done
dependencies: [A-RUN-003]
allowed_paths: [tests/stress/, tests/run_tests.gd, scripts/, docs/, VALIDATION_REPORT.txt]
forbidden_paths: [battle/, fighter/, data/, presentation/, frontend/]
required_specs: [AGENTS.md, ARCHITECTURE.md]
required_checks: [godot --headless --path . -s res://tests/run_tests.gd, python3 scripts/static_validate.py]
---
# Task
## Goal
Obtain real runtime evidence for the existing deterministic 10,000-tick stress suite.
## Context
Stress source is authored and registered, but current reports correctly say runtime was not executed.
## Existing Behavior To Preserve
The deterministic scripted input and existing assertions remain intact.
## Required Change
Run the suite under pinned Godot and record factual output; fix only runner wiring defects proven by that execution.
## Public/API Contract
The global runtime command exercises the stress suite through `tests/run_tests.gd`.
## Implementation Constraints
Do not weaken tests or claim pass from static analysis.
## Edge Cases
If runtime is unavailable, leave status blocked/NOT EXECUTED with evidence.
## Tests
Godot editor import and runtime runner, plus static validation.
## Acceptance Criteria
Real runtime result is recorded, including failure output if any.
## Completion Evidence
Godot Verify CI run 32553549357 (2026-08-22) executed the global runtime
runner with the pinned Godot 4.7.2 stable binary. `Simulation Stress tests`
reported 7 passed, 0 failed, including exactly 10,000 render-free simulation
ticks and a fresh-Battle replay hash match across 1,800 recorded frames.

The successful process also emitted an exit warning for 2,900 leaked ObjectDB
instances. This verification task does not change gameplay or test code; the
warning requires separate diagnosis before it can be treated as resolved.
## Rollback / Recovery Notes
Revert only verified runner fixes; preserve test evidence.
## Out of Scope
Changing gameplay to improve stress behavior without a separate defect task.
