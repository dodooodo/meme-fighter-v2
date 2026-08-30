# Character Content Index

One read-only join across the three files that decide what a character actually
does on screen. `CharacterValidator`, the CLI report, and (later) the editor dock
all read the same index, so a red CI check and a red row in the report always
mean the same thing.

## What gets joined

```
character_manifest.tres
├─ gameplay/move_set.tres → moves/*.tres      move id, frame data, damage
├─ presentation/character_presentation.tres   move_id ⇄ animation_key
│                                             state_key ⇄ animation_key
└─ presentation → fighter_visual_scene
   ├─ SpriteFrames                            which animations can actually play
   └─ manifest.json                           fps, loop, pivot, source frames
```

`SpriteFrames` is the truth for whether an animation can play. The build
manifest supplies fps/loop/source metadata for display and is allowed to be
missing without failing the index.

## Two facts worth knowing before you edit bindings

**`MoveData.animation_id` is not read at runtime.** Nothing outside the
validator reads that field. The animation a move plays comes from the
presentation binding resolved by `CharacterPresentationData.animation_for_move`.
Setting `animation_id` on a move does not bind anything.

**An unbound move plays the wrong animation, not no animation.** It resolves to
`PresentationAnimationIds.ATTACK_FALLBACK` (`attack`); no character package
builds an `attack` animation, so `ProductionFighterVisual._generic_fallback`
catches it and substitutes `stand_light`. Verified on salad_cat: an unbound
`salad_wave_l1` plays the light-attack animation with `visible = true` behind a
single `push_warning`. A charge special that looks like a jab is much harder to
spot than a blank frame, which is why this is checked rather than left to
playtesting.

## Checks

| Code | Severity | Meaning |
| --- | --- | --- |
| `move.unbound` | error | Move has no presentation binding and is not allowlisted |
| `move.unbound_allowlisted` | warning | Known unbound move declared in the allowlist |
| `move.animation_missing` | error | Binding names an animation absent from SpriteFrames |
| `state.animation_missing` | error | Same, for a state binding |
| `move.variant_gap` | error | Conditioned bindings leave a resource value uncovered and there is no unconditional fallback |
| `move.unknown_resource` | error | Binding conditions on a resource the character does not declare |
| `mode.required_animation_missing` | error | A mode pack lacks an animation it declares as required |
| `mode.partial_pack` | warning | A mode pack covers only part of the base animation set |
| `animation.orphan` | warning | Built animation no binding references |
| `animation.fallback_missing` | warning | The fallback animation itself is absent from SpriteFrames |

Overlapping and ambiguous resource variants are already rejected by
`CharacterPresentationData._validate_resource_variant_groups`; this index adds
the uncovered-gap case that check does not cover.

## Running it

```bash
./scripts/content_report.sh                      # full markdown to stdout
./scripts/content_report.sh --output report.md   # write to a file
./scripts/content_report.sh --issues-only        # verdict only, used by verify.sh
```

`scripts/verify.sh` runs `--issues-only`. Errors fail the build; warnings never
do.

## The editor dock

`addons/character_content_inspector` renders the same index inside Godot, under
the **Characters** dock. It is read-only; nothing in it writes to disk.

- **Characters** list — every non-template package, with its error count.
- **Moves** — move id, bound animation, `startup/active/recovery`, damage, and
  status (`ok`, `MISSING ANIMATION`, `UNBOUND`, `allowlisted`).
- **States** — the same for state bindings, including resource-conditioned
  variants shown as `animation [resource min-max]`.
- **Animations** — every built animation with frame count, fps, loop, and
  whether any binding references it.
- **Issues** — the character's findings, using the same codes and wording CI
  prints.

Selecting a move, state, or animation plays it from the character's real
`SpriteFrames` at the build manifest's fps and loop setting. Selecting a move
with no usable binding says so rather than showing a stale frame.

The **Import art pack** button is deliberately inert; the GUI import path is
`A-COL-010`. Build art packs with `scripts/build_art_manifest.py` until then.

## The unbound-move allowlist

`content/validation/unbound_moves_allowlist.json` declares moves knowingly
shipped without a binding. It is a shrinking debt list, not a mute button:

- Delete an entry in the same PR that adds the move's binding.
- Every entry needs a `reason` and a `blocked_on`.
- Adding an entry to make CI green without both is a review failure.

Current entries are the Golden Pair's charge-special tiers
(`magic_circle_l1/l2/l3`, `salad_wave_l1/l2/l3`). Those animations have never
been built, so all six currently play the light-attack animation when they
fire.
