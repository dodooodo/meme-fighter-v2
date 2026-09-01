---
id: A-COMBAT-001
stage: A
type: implementation
status: in_progress
dependencies: []
allowed_paths: [battle/, fighter/, data/, content/, presentation/, debug/, telemetry/, tests/, scripts/, docs/, ARCHITECTURE.md, README.md, IMPLEMENTATION_REPORT.md, VALIDATION_REPORT.txt, PRODUCTION_CHARACTER_ASSET_REPORT.txt]
forbidden_paths: [frontend/, assets/]
required_specs: [AGENTS.md, ARCHITECTURE.md, docs/architecture/TESTING.md, docs/architecture/CHARACTER_PACKAGE.md, docs/architecture/TELEMETRY.md]
required_checks: [python3 scripts/static_validate.py, godot --headless --path . -s res://tests/run_tests.gd, bash scripts/verify.sh]
---
# Task

## Goal

Complete the existing Meme Fighter V2 combat implementation as a deterministic, data-driven 14-character playable Alpha using the canonical 60 Hz universal rules and roster mechanics supplied for this task.

## Context

The repository already contains mature BattleSimulation, fighter HFSM, data resources, replay/snapshot/hash systems, temporary entities, roster mechanics, CPU, presentation, debug, telemetry, and tests. This task continues that codebase. It must not create a replacement project or character-specific combat managers.

## Existing Behavior To Preserve

BattleSimulation remains the sole gameplay authority; presentation remains observational; InputFrame keeps the five-button contract; replay truth remains normalized input; character identity remains data-driven; existing stable roster, move, resource, presentation, and package IDs remain stable.

## Required Change

Migrate universal combat to the canonical 60-second/100-meter/approximately-1000-HP Alpha rules; add generic combo scaling, throw tech/protection and throw-only movement invulnerability, contextual buffering and minimum charge release behavior, same-tick contact arbitration, deterministic design-unit conversion, summon anti-infinite controls, canonical roster statistics, all 14 character mechanics and moves, asset-binding metadata/reporting, CPU identity/difficulty data, training/debug/telemetry coverage, snapshot/hash/replay coverage, and automated validation.

## Public/API Contract

No new permanent gameplay buttons. No character-ID branches in generic combat core. New future-affecting state must be captured/restored/hashed. Actual production asset inventory is authoritative for presentation binding.

## Implementation Constraints

Prefer the existing generic schemas and runtime systems. Add only generic extensions that are required to represent the canonical rules. Use integer/fixed-tick deterministic gameplay arithmetic. Never derive collision or timing from sprite alpha, texture bounds, render delta, or AnimationPlayer timing.

## Edge Cases

Same-frame strike/throw and throw/throw; lethal trades; charge taps shorter than 3F; hitstop during charge; throw protection after stun; throw versus jump/backstep; summon block/hit lockout; Sticky one-time extension; True Face resource exhaustion; Courage reset/cashout; Last Stand zero Resolve/KO/throw interruption; KO/timeout/entity cleanup; snapshot/replay in every new state.

## Test Plan

Change type: feature

Expected test levels: static, unit, component, integration, smoke, determinism

Pre-change expected failure / characterization: baseline static validation passes, but current source/data still use 5940F rounds, 5000-HP roster values, 6F dash neutral tolerance, old throw timing with no tech/protection, no universal combo scaling/defender meter, and immediate sub-3F charge release.

Post-change required checks: focused combat/data/roster/snapshot/replay tests; 14x14 roster smoke; deterministic stress; static validation; project verification; Godot runtime when executable is available.

## Documentation Impact

Expected: required

Affected docs: combat architecture/current behavior, task handoff, generated combat/asset-binding/balance reports.

## Acceptance Criteria

All 14 roster entries load with complete base moves, three charge levels where applicable, Ultimate, unique mechanics, canonical movement/HP/meter/timer/throw/scaling behavior, deterministic entities and resources, generated production bindings, CPU/debug/training/telemetry support, snapshot/restore/hash/replay coverage, and passing static validation. Runtime checks must be reported NOT EXECUTED if Godot is unavailable.

## Rollback / Recovery Notes

The input contract and stable IDs are unchanged. Generic extensions are additive and canonical-tuning migrations are isolated in data/resources and shared combat systems, so changes can be reverted by subsystem without replacing the repository.

## Out of Scope

Online/rollback networking, ranked play, platform SDKs, monetization, new permanent buttons, RPG progression, new roster characters, production art generation, unrelated frontend rewrites.
