# Two Box Fighting — Production Art Asset Contract (M9P)

## Core rule

**PRODUCTION ART IS MULTI-PACK.** A fighter is not represented by one universal sprite sheet.
Gameplay Entity and Presentation Asset are separate concepts. A single move may render simultaneously as:

- Fighter Body Animation
- Attached Effect
- Detached Projectile
- World Hazard
- Screen Overlay / Ultimate Background

Only Gameplay Simulation decides combat. Presentation texture size, pivot, aspect ratio, visual scale, opacity, animation FPS, VFX lifetime, and screen coverage never define hitbox, hurtbox, damage, meter, startup/active/recovery, projectile speed, mode duration, Snapshot state, Replay identity, or BattleStateHasher state.

## PACK A — BASE_FIGHTER

Purpose: normal fighter body only.

Contract:
- 10 source sheets.
- 5×5 each.
- 250 frames total.
- Existing deterministic grid/gutter crop pipeline remains authoritative.
- Canonical facing RIGHT; mirror in Presentation when facing left.
- FEET_CENTER pivot.
- Shared runtime canvas remains allowed for backward compatibility.
- `manifest_version = 3`, `pack_type = BASE_FIGHTER`, `mode_id = ""`.

Body animation keys remain the current 23-key contract. `special_neutral` and `ultimate` remain body animation only.

Allowed inside the body pack: character body, charge/release gesture, recoil, recovery, tiny attached muzzle/mouth flash that belongs to the pose.

Do **not** draw full projectile travel, screen-wide beam lifetime, persistent trap, large detached hazard, full-screen Ultimate background, summoned companion lifetime, or a complete transformed-mode moveset.

## PACK B — MODE_FIGHTER

Purpose: Install / transformation appearance with a materially different silhouette or a complete alternate moveset.

Contract:
- Manifest-driven.
- No 250-frame requirement.
- No 10-sheet requirement.
- Individual transparent PNG/WebP frames or explicit manifest-defined grid/strip source are allowed.
- Frame width and height may differ.
- No square runtime canvas requirement.
- Default runtime output is `TIGHT_PIVOT`: source scale is preserved; only transparent-margin crop is performed.
- Every frame stores `pivot_pixels` using FEET_CENTER.
- `visual_scale` is Presentation-only.

A transformed fighter must contain every gameplay-visible body state required while that mode is active. Do not fall back to the normal body for missing guard/hit/KO/attack poses unless the art contract explicitly permits a placeholder during development.

### SUPER_DOGE minimum body states

`idle`, `walk_forward`, `walk_back`, `crouch`, `jump`, `landing`, `guard_stand`, `guard_crouch`, `blockstun`, `hitstun`, `thrown`, `knockdown`, `getup`, `ko`, `dash_forward`, `backstep`, `stand_light`, `stand_heavy`, `crouch_low`, `air_attack`, `ground_throw`, `special_neutral`, plus any mode-specific move animation.

### TRUE_FACE minimum body states

`idle`, `walk_forward`, `walk_back`, `crouch`, `jump`, `landing`, `guard_stand`, `guard_crouch`, `blockstun`, `hitstun`, `thrown`, `knockdown`, `getup`, `ko`, `dash_forward`, `backstep`, `pink_true_light`, `pink_true_heavy`, `pink_true_low`, `pink_true_air`, `ground_throw`, `pink_true_special`, `pink_true_special_l2`, `pink_true_special_l3`, `pink_true_exit`.

## PACK C — WORLD_EFFECT / PROJECTILE / HAZARD

Purpose: detached art that exists independently of the fighter body.

Examples: projectile, beam visual, shockwave, trap, tentacle, bowl, ground impact, magic circle, aura, speed trail.

Contract:
- Transparent RGBA source.
- Arbitrary aspect ratio.
- No square-canvas rule.
- Individual frame files are preferred.
- Explicit horizontal strip, vertical strip, or explicit manifest-defined grid is supported.
- The builder never infers gameplay size from image bounds.
- `pivot_pixels` is Presentation-only. Center is the default for detached effects.
- Gameplay entity position/speed/lifetime/collision remains authoritative.

Recommended source layout:

```text
pink_star/projectiles/sonic_l3/
  001.webp
  002.webp
  ...
```

A 384×128 projectile and a 512×192 ground hazard are valid production assets.

## PACK D — ULTIMATE_SCREEN

Purpose: full-screen background, cut-in, or overlay.

Contract:
- Screen-space, not Fighter Node2D space.
- Canonical runtime output: 1280×720.
- Source may be 1280×720, 1920×1080, 2560×1440, or another approximately 16:9 size.
- RGB or RGBA accepted.
- Source is aspect-preserving center-cropped when necessary, then resized to 1280×720; never stretched.
- Static and multi-frame manifests are supported.
- Presentation length cannot extend or shorten Gameplay Ultimate timing/freeze.

World-positioned Ultimate objects such as falling bowl, tentacles, target marker, or ground shockwave are **not** baked into the screen background. They belong to WORLD_EFFECT / HAZARD.

## PACK E — ATTACHMENT

Purpose: weapon, shield, extra item, mode weapon, or cosmetic presentation part attached to a named socket.

Contract:
- Transparent texture or visual scene.
- Socket-based.
- Supported anchors: `FEET_CENTER`, `BODY_CENTER`, `HEAD`, `MOUTH`, `LEFT_HAND`, `RIGHT_HAND`, `WEAPON`, `CUSTOM_OFFSET`.
- Offset/rotation/scale/mirroring are Presentation-only.
- Attachment bounds never become gameplay collision.

## Transformation handoff

Base Ultimate art only needs to show normal form → transformation/casting → handoff. When gameplay later exposes an authoritative mode id on a particular simulation frame, Presentation switches to the corresponding `ModePresentationBinding` on that frame. Animation completion never activates gameplay mode.

M9P intentionally adds no Doge/Pink gameplay mode state. The Presentation controller exposes `apply_authoritative_mode_id()` as the one-way handoff API for the future gameplay mode system.

## Builder CLI

BASE_FIGHTER stays backward compatible:

```bash
python3 scripts/build_character_assets.py --character salad_cat --source <source.zip>
```

MODE_FIGHTER:

```bash
python3 scripts/build_mode_character_assets.py --spec super_doge_mode_pack.json --source-root <source-dir>
```

PROJECTILE / WORLD_EFFECT / HAZARD / ATTACHMENT:

```bash
python3 scripts/build_effect_assets.py --spec pink_sonic_l3.json --source-root <source-dir>
```

ULTIMATE_SCREEN:

```bash
python3 scripts/build_ultimate_screen_assets.py --spec cthulhu_background.json --source-root <source-dir>
```

## Failure / fallback policy

Missing optional Presentation art must not crash combat. Existing greybox/placeholder Presentation may be used during development, but validators must report missing required production bindings when a pack is declared production-required.
