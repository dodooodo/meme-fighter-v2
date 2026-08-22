# Telemetry Contract

## CURRENT

No production telemetry transport, identity service, or analytics store exists
in v2. Existing replay data is deterministic gameplay evidence, not analytics.

## TARGET

Telemetry is observational and non-blocking. It must not write gameplay state,
wait on network/DB, or emit one event per simulation frame. Transport belongs
outside battle/fighter core behind a platform/service boundary.

### Event envelope

All events carry explicit scalar fields:

```text
event_name, event_version, occurred_at, installation_id, session_id,
user_id? , match_id? , platform, build_version, payload
```

`user_id` is optional and must be a pseudonymous product identity, not an email
or raw platform account identifier. Event names use lower-case dotted domains
(for example `match.completed`); incompatible payload changes increment
`event_version`.

Match events include mode, participants/character IDs, result, duration, and
replay correlation ID where available. Move events are aggregate/action events,
not frame polling. Performance events include platform/build and bounded timing
metrics. Mastery events express player progression milestones, not raw inputs.

Replay files retain input frames plus replay metadata/final hash as defined by
combat architecture. A replay correlation ID may connect evidence to telemetry,
but replay payloads are not copied into analytics events.

### Privacy

Collect the minimum needed for stated product decisions; document purpose and
retention before adding a sink. Avoid content/input capture, secrets, and direct
identifiers. Respect platform consent/deletion requirements in the future
platform adapter task.

## MIGRATION

Define local event sinks and schemas in task packets before any backend/storage
integration. Add transport only after it can fail independently of simulation.
