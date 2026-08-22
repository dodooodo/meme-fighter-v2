# Battle core rules

`battle/` is deterministic gameplay authority. Keep it independent of UI,
presentation, platform SDKs, HTTP, and telemetry transport. Use integer,
fixed-tick simulation state. Any future-affecting change needs explicit
snapshot/restore/hash treatment plus replay and determinism regression tests.
Do not introduce character-ID branches; add a generic data contract only when
the task/spec proves one is needed. See `../ARCHITECTURE.md` and root `AGENTS.md`.
