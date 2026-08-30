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
template, and focused test commands. Niu Lai now also uses a manifest-backed
package, package-owned moves, and recovered production action frames; the
remaining ten roster characters still use central resources. A3 contributor
tooling provides domain ownership,
role PR contracts, read-only balance exports, a validation-first round-trip
strategy, a manifest-driven art build entrypoint, mechanic authoring guidance,
and repeatable merge-conflict simulation. A4 now provides local identity,
versioned JSONL telemetry for match/move/mastery/performance evidence, bounded
failure isolation, and replay correlation. A5 now implements the third packaged
fighter (Doge), a manifest-discovered four-fighter Character Select including
Niu Lai, Training minimum, and the six-step Tutorial that covers the seven
roadmap controls.
Automated runtime, determinism, package, and live-scene smoke evidence is green;
the A5 human play checklist remains the release-acceptance boundary.

## Dependencies and workstreams

```text
A-RUN-001 ─┐
A-RUN-002 ─┼─> A-RUN-005 (CI required gate)
A-RUN-003 ─┤
A-RUN-004 ─┘

A-VS-001 ─────────────────────────> later Golden Pair presentation/feel work
A-MOD-001 ─> A-MOD-002 ─> A-MOD-003 ─> A-MOD-004 ─> A-MOD-005 ─> A-MOD-006 ─> A-MOD-007
A-COL-003 ─> A-COL-004; A-COL-001/002/005/006/007 are independent
A-DATA-001..008 ─> local Event Envelope v1 + replay-correlated JSONL
A-MVP-001..004 ─> packaged Doge; A-MVP-005..007 ─> select/training/tutorial
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
| A-RUN-007 | Make the art pipeline run on Python 3.9 | none | done — output-neutral; a MODE_FIGHTER pack builds on both 3.9 and 3.13 |
| A-COL-001 | Add domain-separated CODEOWNERS | none | done |
| A-COL-002 | Add five role-based PR templates | none | done |
| A-COL-003 | Export balance tables as CSV/Markdown | none | done |
| A-COL-004 | Define validation-first balance import strategy | A-COL-003 | done — import remains intentionally export-only |
| A-COL-005 | Add one-command art manifest build | none | done |
| A-COL-006 | Add mechanic authoring guide | none | done |
| A-COL-007 | Simulate four contributor branches | none | done |
| A-COL-008 | Join gameplay, presentation, and built art into one validated index | none | done — validation, markdown report, and CI gate green |
| A-DATA-001 | Add local identity vocabulary | none | done |
| A-DATA-002 | Add Event Envelope v1 | none | done |
| A-DATA-003 | Emit match summaries | none | done |
| A-DATA-004 | Aggregate move telemetry | none | done |
| A-DATA-005 | Derive mastery events | none | done |
| A-DATA-006 | Sample performance events | none | done |
| A-DATA-007 | Persist bounded local JSONL | none | done |
| A-DATA-008 | Correlate match summaries to replay files | none | done |
| A-MVP-001 | Migrate Doge package | A-MOD-007, A-DATA-001 | in progress — implementation and automated checks complete; human play pending |
| A-MVP-002 | Split Doge MoveData resources | A-MOD-007 | in progress — implementation and automated checks complete |
| A-MVP-003 | Bind Doge production presentation | none | in progress — feet-pivot regression and rendered alignment review green; in-battle human review pending |
| A-MVP-004 | Regress Doge charge behavior | none | in progress — focused snapshot/hash and global replay suites green |
| A-MVP-005 | Add manifest-backed Character Select | A-MOD-007 | in progress — original selector layout restored; Niu Lai expands the available roster to four; live-scene smoke and rendered review green |
| A-MVP-006 | Add Training minimum | none | in progress — automated checks green; human play pending |
| A-MVP-007 | Add Tutorial minimum | none | in progress — automated checks green; human play pending |
| A-CHAR-001 | Add Niu Lai production character | A-MOD-007 | in progress — implementation/static checks complete; Godot runtime and human play pending |

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
- A4 is local-only. Remote retention, consent/deletion, hard-crash capture,
  ingestion quality, and analytics storage remain later-stage work.
- A5 automated evidence cannot certify animation timing, control feel, or the
  clarity of prompts during play; use `A5_MANUAL_VERIFICATION.md` before release.

## Stage gate

Do not mark Stage A complete until master-roadmap A0–A4 acceptance is met,
including actual CI runtime evidence, Golden Pair coverage/soak, Character
Package validation, and local telemetry. Task completion is evidence; it does
not waive the Stage gate.

## Recommended order

The project owner accepted A-RUN-005's external Rulesets limitation on
2026-08-22. The A-MOD-003 through A-MOD-007 modular stream is complete; retain
the corresponding task packets and verification evidence as implementation
authority for later character-package work. A-COL-001 through A-COL-007 are
also complete. The balance workflow remains export-only until a later task
implements the complete validation, preview, atomic apply, and rollback
contract; this is the accepted A-COL-004 strategy, not a partial importer. A4
local telemetry is complete; retain its envelope/ADR as authority and defer all
HTTP, remote storage, consent, retention, and account identity work to B4 or an
explicit platform/privacy task. A5 implementation follows next: keep the seven
packets active until the owner completes the manual checklist, then record that
evidence before marking the aggregate done.
