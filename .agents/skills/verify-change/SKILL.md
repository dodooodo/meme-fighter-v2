---
name: verify-change
description: Verify a scoped Dorian change without claiming unexecuted runtime work.
---

# Verify Change

Read the active task, changed paths, and
[TESTING.md](../../../docs/architecture/TESTING.md). Run packet
`required_checks` first and select proportional evidence. Let
`validate_task.py` resolve the local merge-base; CI passes the exact PR base SHA.

- resources/manifests/config/scripts/CI: static/schema plus parser/syntax/script checks;
- isolated deterministic logic: unit tests;
- character/mechanic/binding work: component tests;
- runtime boundaries: integration tests;
- viable game flow: smoke test;
- simulation, snapshot, hash, or future-affecting state: replay/determinism regression;
- UI flows, visual work, or performance-sensitive work: E2E, visual, and/or stress evidence.

Always run `python3 scripts/static_validate.py` and `bash scripts/verify.sh`
after targeted checks unless the packet documents an exception, then run task
scope validation against the task base. Runtime is PASS only when Godot actually
executes; unavailable runtime is NOT EXECUTED, never PASS. Report every selected
level and global/scope result as PASS, FAIL, or NOT EXECUTED, including evidence.
If any code, runtime config, gameplay data, script, or test-sensitive resource
changes after verification, rerun affected checks for the final diff.
