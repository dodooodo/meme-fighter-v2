# Dorian Legacy Audit

`../Dorian` is a read-only TypeScript/Phaser implementation. It is evidence,
not an architecture authority for v2.

## Reusable references

- Web deployment and release workflow: `.github/workflows/ci.yml`,
  `.github/workflows/release.yml`, `render.yaml`, and the build/server split.
- Online boundary: `src/net/Transport.ts`, `LockstepSession.ts`,
  `WebRtcTransport.ts`, and `server/` demonstrate transport abstraction,
  input batching, room-code matchmaking, and server integration tests.
- Protocol/security lessons: shared `src/net/protocol.ts`, bounded WebSocket
  payloads in `server/index.ts`, and documented client/server responsibilities.
- UX/docs: `src/scenes/OnlineLobbyScene.ts` and `docs/networking/` are useful
  product/operational references for a later online task.

## Do not transplant

- Phaser/render-loop architecture, TypeScript simulation types, Node module
  boundaries, or existing wire protocol cannot be copied into Godot combat.
- The legacy WebRTC policy deliberately uses STUN plus WebSocket relay fallback;
  it is a product/cost decision to revisit, not a v2 networking decision.
- Legacy's online implementation is not proof that v2 has rollback readiness.

## v2 gaps (intentional at this stage)

v2 has no web export/PWA pipeline, matchmaking/server, WebSocket/WebRTC/TURN,
production protocol, authentication/security service, telemetry sink, or
deployment CI. These remain roadmap-gated work outside this foundational task.
