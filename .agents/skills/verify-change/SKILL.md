---
name: verify-change
description: Verify a scoped Dorian change without claiming unexecuted runtime work.
---

# Verify Change

Read the active task and changed paths. Run its `required_checks` first.

- Gameplay core/data changes: targeted character tests plus snapshot/replay/hash
  regression and static validation.
- Presentation/assets: asset validator and presentation tests.
- Scripts/CI/docs: syntax/parse checks, link checks, and scope validation.

Always run `python3 scripts/static_validate.py` and `bash scripts/verify.sh`
after targeted checks unless the task documents an exception. Runtime is PASS
only when Godot actually executes. Report unavailable runtime as NOT EXECUTED
and CI configuration separately from local execution.
