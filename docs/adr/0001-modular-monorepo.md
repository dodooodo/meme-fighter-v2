# ADR 0001: Modular monorepo direction

## Status
Accepted

## Context
v2 is one Godot repository today; the roadmap anticipates gameplay, content,
presentation, frontend, platform, and service boundaries.

## Decision
Keep one canonical v2 repository and evolve explicit module boundaries inside it.

## Consequences
Coordination stays simple now, while task scopes and contracts prevent core
coupling. Future backend/platform modules require explicit task/ADR decisions.
