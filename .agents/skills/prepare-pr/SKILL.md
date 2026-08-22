---
name: prepare-pr
description: Prepare a review-ready Dorian task summary from a validated diff.
---

# Prepare PR

Read the task packet, `git diff`, and verification output. Produce:

```text
Task ID:
Goal:
Files changed:
Behavior change:
Architecture impact:
Determinism impact:
Snapshot/replay impact:
Telemetry impact:
Tests (PASS / FAIL / NOT EXECUTED):
Acceptance:
Risk:
Deferred:
```

Do not infer runtime success, expand scope, or reproduce architecture specs in
the summary. Link to their canonical paths instead.
