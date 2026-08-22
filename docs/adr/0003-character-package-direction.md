# ADR 0003: Character Package direction

## Status
Accepted

## Context
Current roster resources are central while production content needs isolated,
low-conflict packages.

## Decision
Adopt manifest-discovered Character Packages incrementally; preserve current
data layout until individual migration tasks prove compatibility.

## Consequences
Character identity remains `CharacterData.id`; catalog/package work cannot
introduce generic-core character branches or force a mass roster migration.
