---
name: prepare-pr
description: Prepare a review-ready Dorian task summary from a validated diff.
---

# Prepare PR

Read the task packet, committed diff, and actual verification/CI output. Produce:

```text
Task ID:
Goal:
Files changed:
Behavior change:
Architecture impact:
Determinism impact:
Snapshot/replay impact:
Telemetry impact:
Docs impact:
Branch:
Commit(s):
CI state:
Tests (PASS / FAIL / NOT EXECUTED):
Acceptance:
Risk:
Deferred:
```

Confirm the branch is not `main`, the committed diff is the verified final diff,
and the PR uses the intended base. Do not infer runtime/CI success, expand scope,
or reproduce architecture specs in the summary. Never open/claim ready a PR with
failed required checks; do not merge without authorization. Link to canonical
specs instead.
