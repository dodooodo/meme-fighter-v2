---
id: A-DATA-006
stage: A
type: implementation
status: done
dependencies: []
allowed_paths: [telemetry/, battle/battle_scene.gd, tests/telemetry/, tests/run_tests.gd, project.godot, docs/architecture/, docs/roadmap/, docs/tasks/]
forbidden_paths: [fighter/, data/, frontend/, presentation/, assets/, server/]
required_specs: [AGENTS.md, docs/architecture/TELEMETRY.md]
required_checks: [godot --headless --path . -s res://tests/telemetry/run_telemetry_tests.gd, bash scripts/verify.sh]
---

# Performance Events

## Goal

Capture bounded local runtime health evidence without frame-by-frame analytics.

## Context

Stage A lacks data for slow frames, load regressions, memory, and runtime errors.

## Existing Behavior To Preserve

Simulation scheduling and gameplay time remain authoritative and unchanged.

## Required Change

Add sampled FPS buckets, long-frame events, memory snapshots, load and asset-pack
load durations, and sanitized crash/error markers.

## Public/API Contract

Timing values are bounded numeric metrics with platform/build context inherited
from the envelope.

## Implementation Constraints

Sampling is render/service-side, frequency-limited, and cannot stall or feed back
into simulation.

## Edge Cases

Invalid/negative durations, repeated long frames, unavailable memory readings,
oversized error messages, and fatal markers that cannot guarantee hard-crash flush.

## Test Plan

Change type: feature

Expected test levels: unit, integration, performance

Pre-change expected failure / characterization: no performance telemetry exists.

Post-change required checks: focused telemetry and global verification.

## Documentation Impact

Expected: required

Affected docs: telemetry contract.

## Acceptance Criteria

Every roadmap performance category has a bounded test-covered API or sampler.

## Rollback / Recovery Notes

Remove scene sampling and additive service APIs.

## Out of Scope

Profiler traces, remote crash SDKs, device fingerprinting, and alerting.
