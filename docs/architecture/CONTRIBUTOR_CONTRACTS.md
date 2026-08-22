# Contributor Contracts

| Role | Owns / may edit | Normally must not edit | Required validation / escalation |
| --- | --- | --- | --- |
| Gameplay core | `battle/`, `fighter/`, shared gameplay data/tests | presentation/platform integration | static + runtime + replay/snapshot regressions; escalate any contract change |
| Character / skill | assigned package/data, character tests | generic core, another character package | data/static + focused character test; escalate a missing generic mechanic |
| Balance | assigned `MoveData`/`CharacterData`, balance docs | runtime systems, art bindings | data/static + affected roster/replay test; escalate schema changes |
| Art / technical art | `assets/`, `presentation/`, asset scripts/tests | combat values and simulation | asset validation + presentation tests; escalate missing binding/fallback |
| Frontend | `frontend/`, UI presentation consumers | battle authority or direct combat mutation | static + affected runtime/UI tests; escalate required service/API |
| Backend | future server/platform boundary | Godot Nodes/scenes and combat core | service tests + contract review; escalate identity/match/telemetry schema |

`allowed_paths` in the active task packet takes precedence for a specific task.
If a role needs another boundary, do not make an opportunistic edit: propose a
new task/dependency or get the owner to review it.
