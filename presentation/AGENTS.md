# Presentation rules

Presentation is a read model: it may consume simulation state and events, but
may not mutate combat, match, fighter, projectile, snapshot, or replay state.
Animation, timers, tweening, assets, audio, and camera may be non-authoritative
only. Keep presentation resources separate from `CharacterData`.
