---
name: start-task
description: Initialize one Dorian task safely with branch and worktree isolation.
---

# Start Task

Input: Task ID.

1. Read root/nested `AGENTS.md` and locate `docs/tasks/active/<TASK-ID>.md`
   (or its completed packet only for audit work). Read metadata, dependencies,
   required specs, and required checks; stop if the packet is missing, blocked,
   or dependencies are unresolved.
2. Inspect `git status --short`, `git branch --show-current`, `git worktree list`,
   and `git log -1 --oneline`. If a remote is available, fetch it and compare the
   intended base (normally `origin/main`).
3. Reuse a matching existing task branch/worktree. Otherwise, if the current
   workspace is clean and idle, create/switch to the task branch from the
   intended base (including when currently on `main`). If it has unrelated work,
   another task branch, another active user, or concurrent task work, create a
   separate worktree plus task branch.
4. Never discard, stash, reset, clean, overwrite, or delete unrelated work.

Output:

```text
Task:
Base:
Branch:
Workspace/worktree:
Dependencies:
Working tree:
Required specs:
Required checks:
Recommended test plan:
```

Use `task/<TASK-ID>-<slug>` by default, or `fix/<TASK-ID>-<slug>` for a repair
when that better matches the packet. This skill initializes work only; it does
not replace the implementation, verification, commit, or PR procedures.
