# Mechanic Authoring Guide

This guide turns a character or skill idea into the smallest existing generic
contract that can express it. The default rule is simple: when data can express
the difference, use data instead of code. A character package must never add a
`character_id` branch to generic battle or fighter code.

## Start with the authority question

Before choosing a type, classify the requested behavior:

- Damage, timing, collision, movement, resources, statuses, modes, summons,
  hazards, win conditions, or anything that can change a future simulation tick
  is gameplay. It belongs in immutable gameplay data plus deterministic runtime.
- Animation, sprites, VFX, audio, camera, HUD, and screen effects that only
  observe gameplay facts are presentation. They must not decide or mutate
  gameplay state.
- Display names, discovery, availability, portraits, and package identity belong
  to the character manifest/catalog boundary, not fighter runtime state.

## Decision path

### 1. Existing MoveData or typed move payload

Use `MoveData` and its existing typed children when the behavior belongs to one
move: frames, damage/stun, boxes, travel, cancel windows, throws, projectile
spawns, per-hit payloads, armor/counter configuration, and on-start/on-hit/
on-block/on-complete effects. Keep every move ID stable and unique within the
character package.

Do not add a new effect or runtime component merely to avoid authoring an
existing field. Validate cancel targets, spawn frames, projectile IDs, and art
bindings with the character validator.

### 2. GameplayEffectData

Use `GameplayEffectData` for a deterministic action executed at an existing
generic lifecycle seam. Good fits include applying/removing a status, changing
a configured resource, entering/exiting a mode, deterministic positioning,
spawning a typed temporary entity, starting a sequence, or another action
already represented by its typed enum and payload.

Choose it when all of these are true:

- the action is triggered by an existing move/hit/block/completion seam;
- its configuration can remain immutable Resource data;
- its result can be applied through the generic executor;
- any resulting mutable state already has snapshot/restore/hash coverage.

Do not use it as a stringly typed script callback, arbitrary command language,
presentation trigger, or place to hide character-specific branching. If the
needed operation is absent, propose a generic effect contract with at least two
credible consumers and architecture/test review.

### 3. CharacterMechanicsData

Use `CharacterMechanicsData` for persistent per-character configuration that
composes existing generic systems: resources, statuses, modes, defense
modifiers, and their typed relationships. This data describes what the
character is configured to support; it is not mutable match state.

Choose it when multiple moves or the character lifecycle share the same typed
configuration. Keep runtime counters, active instances, remaining durations,
and serials in the corresponding generic component, never in the Resource.

Do not use `CharacterMechanicsData` as a miscellaneous dictionary or to hold
presentation assets. A new field requires a typed validation contract and a
generic runtime consumer.

### 4. A new runtime component

A new runtime component is the last option. It is justified only when the
mechanic owns future-affecting mutable state or a deterministic per-tick process
that cannot be represented by the current generic components. Before coding,
write a task packet and answer:

- What single responsibility and state does the runtime component own?
- Why can existing MoveData, GameplayEffectData, CharacterMechanicsData, status,
  mode, resource, projectile, or temporary-entity systems not express it?
- Is the contract generic, typed, and usable without a character ID switch?
- Which composition root configures/ticks it, and in what fixed 60 Hz order?
- How are stable identities validated and resolved during restore?
- Which presentation event exposes observations without granting authority?

Escalate any new architecture seam before implementation. Do not put timers,
delta time, SceneTree callbacks, physics bodies, animation callbacks, network,
telemetry, or platform SDKs into gameplay authority.

## Determinism and state checklist

For every new or changed future-affecting value, all answers below must be yes:

- [ ] The runtime value uses deterministic primitives/value types and advances
      only from the fixed simulation tick and normalized inputs.
- [ ] Resource/Node instance IDs, Dictionary iteration order, wall-clock time,
      floats that can diverge, and presentation state do not decide gameplay.
- [ ] Capture stores the complete future-affecting state in the typed snapshot.
- [ ] Restore validates character/move/effect identity before mutation, rejects
      incompatible input, and restores the exact state plus next serials.
- [ ] The canonical state hash includes the same fields in an explicit stable
      order; resources and memory identities are not hashed.
- [ ] Replay and deterministic re-simulation produce the same final hash.
- [ ] Tests cover capture → advance → restore → re-simulate, invalid restore,
      boundary frames, hitstop/freeze behavior, and duplicate-event/spawn risks.
- [ ] Any snapshot schema change bumps the version and updates all codecs,
      hashers, fixtures, architecture documentation, and regression tests.

Static Resource configuration is not itself snapshot state. Mutable state that
was derived from it still must be captured, restored, and hashed when it can
affect the future.

## Authoring and review loop

1. Copy or edit only the assigned package-owned resources.
2. Reuse stable character, move, effect, projectile, mode, and resource IDs.
3. Run `./scripts/test_character.sh <character_id>` while authoring.
4. If generic runtime code changes, add RED acceptance evidence first, then run
   snapshot, replay, and determinism regressions plus the full repository gate.
5. Use the Skill PR template and report automated and manual evidence separately.

If an idea requires editing a central registry, another character package, or
generic core outside the task packet, stop and split/escalate that dependency.
