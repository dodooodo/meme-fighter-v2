---
id: A-RUN-004
stage: A
type: verification
status: blocked
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
## Rollback / Recovery Notes
Revert only verified runner fixes; preserve test evidence.
## Out of Scope
Changing gameplay to improve stress behavior without a separate defect task.
