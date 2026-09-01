# GATE 3 — Training / Debug Report

This report describes the controls and diagnostics present in the current Gate 3 source tree. Training controls operate on the existing authoritative BattleSimulation and are not normal-match input actions.

## Training controls

- Infinite HP (`Combatant.training_infinite_hp`)
- Infinite Meter (`MeterComponent.training_infinite_meter`)
- Reset Positions / training state
- Set Meter
- Generic resource setter (covers Courage, Face Actions, Resolve and other registered fighter resources)
- Generic status toggle (covers Signal Mark, Sticky, Panic Exit and other registered statuses)
- Generic mode activation/exit (covers Super Doge, Dual Blade, True Face, Last Stand and other registered modes)
- Trigger authored move start effects for training setup (supports trap/summon-style authored effects)

### Dummy policies

- Stand
- Crouch
- Standing Guard
- Crouching Guard
- Guard After First Hit
- Jump
- Backstep

## Debug overlay

- Simulation tick, round state, timer and frame-step state
- Fighter state, Move ID, move frame and phase
- Computed On-Hit / On-Block frame advantage from MoveData timing
- HP, Meter, hitstun, blockstun, hitstop
- Combo hits, combo damage, scaling %, Pink dash-cancel count
- Charge frames / resolved charge level
- Throw protection, Backstep throw-invulnerability flag, Throw Tech pending state
- Active mode and remaining timer
- Generic resources and statuses, including extension marker
- Named visibility for Signal Mark, Panic Exit, Sticky, Courage, Face Actions/Stars, Resolve
- Projectile and temporary-entity counts/state

## Authoritative box visualization

- Pushbox
- Hurtbox
- Active strike Hitbox
- Throw box
- Projectile box
- Area/Trap box
- Hazard box
- Summon hurtbox and active hitbox

All box visualization reads gameplay geometry. It does not derive collision from sprite alpha/texture dimensions.
