# Stage A Execution

## Goal

Produce two production-quality Golden Pair fighters, a mechanic-diverse third
fighter, character-package migration foundation, local telemetry design, and
reliable runtime verification. The master order/gates remain canonical in
[PRODUCTION_ROADMAP.md](../../roadmap/PRODUCTION_ROADMAP.md).

## Current baseline

v2 has a fixed 60 Hz `BattleSimulation`, roster data/resources, presentation,
snapshot/replay tests, `scripts/static_validate.py`, and fail-closed
`scripts/verify.sh`. CI pins Godot 4.7.2. The Golden Pair now uses manifest-backed
character packages with package-owned moves, validation, a safe contributor
template, and focused test commands. The remaining twelve roster characters
still use central resources; telemetry is not yet implemented.

## Dependencies and workstreams

```text
A-RUN-001 ─┐
A-RUN-002 ─┼─> A-RUN-005 (CI required gate)
A-RUN-003 ─┤
A-RUN-004 ─┘

A-VS-001 ─────────────────────────> later Golden Pair presentation/feel work
A-MOD-001 ─> A-MOD-002 ─> A-MOD-003 ─> A-MOD-004 ─> A-MOD-005 ─> A-MOD-006 ─> A-MOD-007
```

`A-RUN-001` through `A-RUN-004` may run in parallel when their path scopes do
not collide. `A-VS-001` is read-only/audit work and can run in parallel. The
modular stream starts with manifest before catalog. CI integrates only after the
runtime command and failure behavior are settled.

## First executable batch

| Task | Purpose | Dependency | Status |
| --- | --- | --- | --- |
| A-RUN-001 | Pin Godot 4.7.2 for local/docs/CI | none | ready |
| A-RUN-002 | Make missing Godot fail verification | none | done |
| A-GOV-001 | Stabilize runtime and governance enforcement | none | in progress |
| A-RUN-003 | Establish one runtime command contract | A-RUN-001 | blocked |
| A-RUN-004 | Execute the existing 10k stress runtime suite | A-RUN-003 | blocked |
| A-RUN-005 | Add CI required verification gate | A-RUN-001..004 | done — repository CI accepted; Rulesets follow-up remains external |
| A-VS-001 | Audit Magic Orange Cat + Salad Cat | A-RUN-005 | done — gameplay coverage evidence merged |
| A-VS-002 | Audit Golden Pair presentation coverage | A-VS-001 | done — bindings gap identified |
| A-MOD-001 | Add CharacterManifest v1 | A-RUN-005 | done |
| A-MOD-002 | Add CharacterCatalog beside RosterRegistry | A-MOD-001 | done |
| A-MOD-003 | Migrate the Golden Pair to packages | A-MOD-002 | done |
| A-MOD-004 | Split Golden Pair MoveData resources | A-MOD-003 | done |
| A-MOD-005 | Add the character package template | A-MOD-004 | done |
| A-MOD-006 | Add package validation | A-MOD-005 | done |
| A-MOD-007 | Add per-character test command | A-MOD-006 | done |

## Integration points and risks

- `scripts/verify.sh`, CI, README, and the version pin must agree exactly.
- The repository is currently private under the personal `dodooodo` account.
  GitHub Rulesets cannot be enforced until it moves to a GitHub Team
  organization; the committed CI workflow runs, but is not yet a
  server-enforced merge gate.
- `RosterRegistry` is currently used by frontend/tests; catalog migration must
  preserve it until all consumers move under an explicit task.
- Golden Pair production quality requires real Godot execution and human feel
  review; source analysis cannot certify it.
- Package paths are target architecture. Do not mass-move the existing roster.

## Stage gate

Do not mark Stage A complete until master-roadmap A0–A3 acceptance is met,
including actual CI runtime evidence, Golden Pair coverage/soak, Character
Package validation, and local telemetry. Task completion is evidence; it does
not waive the Stage gate.

## Recommended order

The project owner accepted A-RUN-005's external Rulesets limitation on
2026-08-22. The A-MOD-003 through A-MOD-007 modular stream is complete; retain
the corresponding task packets and verification evidence as implementation
authority for later character-package work.
