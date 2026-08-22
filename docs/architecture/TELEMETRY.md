# Telemetry Contract

## Current

Stage A provides a local-first telemetry path:

```text
resolved CombatEvent / scene performance sample
    -> TelemetryService
    -> TelemetryMatchAggregator / TelemetryPerformanceSampler
    -> Event Envelope v1
    -> bounded asynchronous LocalTelemetrySink
    -> user://telemetry/telemetry-<session_id>.jsonl
```

Playable local/CPU matches also record replay evidence under
`user://replays/<replay_id>.tbf_replay.json`. There is no production HTTP
transport, identity service, analytics store, consent UI, or retention worker.

## Authority and failure boundary

Telemetry is observational and non-blocking. It must not write gameplay state,
wait on network/DB, or emit one event per simulation frame. `BattleSimulation`
continues to produce deterministic `CombatEvent` facts without importing a
telemetry class. `BattleScene` copies each drained event batch to telemetry and
presentation, then dispatches a bounded sink batch after simulation ticks. One
background writer performs JSONL file access; only explicit scene/application
shutdown boundaries join the writer and drain the remaining queue.

Sink, directory, replay-save, and envelope failures are contained. They may
produce a sanitized `performance.error` when persistence remains available,
but must never change round, match, fighter, snapshot, hash, or replay input
state. The local buffer holds at most 512 events by default and drops the oldest
event on overflow while incrementing an observable drop count.

## Identity vocabulary

| Field | Lifecycle | Notes |
| --- | --- | --- |
| `installation_id` | persisted locally | Random pseudonymous installation identity; not a device fingerprint. |
| `session_id` | application service lifetime | Shared by matches observed by one `TelemetryService`. |
| `match_id` | one battle reset-to-finalization lifecycle | Created before the initial round event. |
| `round_id` | one authoritative round number inside a match | Derived from match ID and round number. |
| `event_id` | one envelope | Monotonic within the session ID. |
| `user_id` | future authenticated product session | Optional pseudonymous ID; never email or raw platform account ID. |

## Event Envelope v1

Every JSONL line is exactly one JSON object:

```json
{
  "event_name": "move.summary",
  "event_version": 1,
  "event_id": "session-...-event-00000001",
  "occurred_at": "2026-08-23T01:02:03Z",
  "installation_id": "installation-...",
  "session_id": "session-...",
  "match_id": "match-...",
  "round_id": "match-...-round-01",
  "build_id": "0.1.0-stage-a",
  "content_version": "stage-a-v1",
  "platform": "macos",
  "payload": {}
}
```

`match_id`, `round_id`, and `user_id` are optional outside their lifecycles.
Required values are explicit JSON scalars; `payload` is a JSON-safe dictionary.
Event names use lower-case dotted domains. Incompatible payload changes increment
`event_version`. Envelope v1 standardizes on `build_id`; the earlier
`build_version` draft name is retired before any remote consumer exists.

Payloads reject Objects/Resources, non-finite numbers, direct account identifiers,
secrets, tokens, raw inputs, and replay input frames.

## Event catalog

### Match and move

- `match.completed`: fighter IDs, winner and participant slot, round count,
  duration in frames/milliseconds, `local_2p`/`vs_cpu`/future `online` mode,
  build/content versions, disconnect reason, and replay correlation/save status.
- `move.summary`: one record per fighter/move used in a match. Contains use, hit,
  block, whiff, punish, counter-hit and damage totals plus close/mid/far distance
  buckets and midscreen/attacker/defender/both-cornered counts.

Move summaries aggregate resolved actions; they are not frame polling. Multi-hit
outcomes may increase hit/block counts while one attack instance increases use
count once. An attack instance with no hit, block, or throw by finalization is
one whiff.

### Mastery

- `mastery.anti_air_success`
- `mastery.whiff_punish_success`
- `mastery.throw_success`
- `mastery.combo_completion`
- `mastery.guard_success`
- `mastery.ultimate_finish`

These events derive from resolved provenance, pre-resolution defender facts, and
authoritative KO/round state. They do not store raw player input. Combo completion
requires at least two linked hits and is emitted when the sequence settles or the
match finalizes.

### Performance

- `performance.fps_snapshot`: bounded FPS histogram.
- `performance.long_frame`: rate-limited frame duration above 33.333 ms.
- `performance.memory_snapshot`: latest sampled static memory bytes.
- `performance.load_duration`: battle setup duration.
- `performance.asset_pack_load_duration`: presentation/asset configuration duration.
- `performance.error`: bounded code/message and explicit fatal marker.

Performance sampling occurs in the scene/service layer. A fatal marker is a
best-effort error observation; Stage A does not claim reliable hard-crash capture.

## Replay correlation

`BattleScene` records the normalized authoritative input stream already defined
by the replay contract. On normal completion, reset, or scene exit, it finishes
the replay with the current deterministic state hash and attempts local save.
The match summary contains `replay_id`, `replay_path`, and `replay_saved`.

Telemetry never embeds or copies replay frames. Failed or empty replay persistence
does not suppress the match summary; its save status remains false.

## Privacy and retention boundary

Collect the minimum needed for stated product decisions. Avoid content capture,
raw inputs, secrets, direct identifiers, and device fingerprinting. Local files
remain on the installation until manually removed; a retention/deletion policy,
platform disclosure, consent flow, and authenticated deletion mechanism are
required before remote ingestion.

## Migration to Stage B

Remote telemetry must preserve this envelope and fail independently of simulation.
Stage B may add bounded batches, retry/drop policy, close-time best-effort flush,
ingestion quality checks, storage, and privacy controls. It must not move HTTP,
database, or platform SDK dependencies into battle/fighter core.
