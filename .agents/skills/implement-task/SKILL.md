---
name: implement-task
description: Implement one Dorian task packet within its declared scope.
---

# Implement Task

1. Read root/nested `AGENTS.md`, then `docs/tasks/active/<ID>.md`.
2. Read each required spec and inspect affected code/tests.
3. Confirm dependencies and paths with `validate_task.py`; plan the smallest change.
4. Implement only the packet's required change.
5. Run targeted tests, each required check, then static/global verification.
6. Run scope validation and review the diff against acceptance criteria.
7. Report task ID, result, checks with PASS/FAIL/NOT EXECUTED, scope impact,
   risks, and deferred work.

Never promote this workflow to architecture truth; follow the linked specs and
task packet. Stop for an escalation if the task needs an unlisted path or new
contract.
