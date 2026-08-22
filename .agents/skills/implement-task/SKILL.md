---
name: implement-task
description: Implement one Dorian task packet within its declared scope.
---

# Implement Task

1. Run `start-task` or perform its equivalent preflight before editing. Read
   root/nested `AGENTS.md`, the task packet, required specs, and affected code.
2. Confirm dependencies and allowed paths. Determine change type and test levels
   with [TESTING.md](../../../docs/architecture/TESTING.md); write the task test plan.
3. For new behavior make acceptance evidence RED first; for bugs reproduce first;
   for refactors establish characterization coverage. For non-behavioral work use
   proportionate non-unit evidence.
4. Implement only the smallest packet-scoped change, make evidence GREEN, then
   refactor. Any later behavior/code-affecting edit requires relevant re-verification.
5. Run targeted, integration/smoke/replay/regression checks as selected, then
   required checks and global verification.
6. Run scope validation, documentation impact review, and final diff review
   against acceptance criteria. Commit only the verified final diff.
7. Report task ID, branch/worktree, result, checks with PASS/FAIL/NOT EXECUTED,
   docs impact, scope/architecture impact, risks, and deferred work.

Never promote this workflow to architecture truth; follow the linked specs and
task packet. Stop for an escalation if the task needs an unlisted path or new
contract.
