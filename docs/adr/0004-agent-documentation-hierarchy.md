# ADR 0004: Agent engineering documentation hierarchy

## Status
Accepted

## Context
Agents and human collaborators need provider-neutral, enforceable instructions.

## Decision
`AGENTS.md` is the entry point; specs, roadmap, and task packets own their
respective truths. `CLAUDE.md` is a thin compatibility layer; skills own only
repeatable workflow.

## Consequences
Rules are linked instead of duplicated. `validate_task.py` enforces declared
scope beyond Markdown guidance.
