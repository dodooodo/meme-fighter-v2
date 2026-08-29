# A5 Human Play Verification

## Evidence status

Automated A5 package, charge, tutorial-model, full-regression, and live-scene
smoke checks pass on Godot 4.7.2. A 1440×900 Character Select render was also
reviewed for clipping, overlap, selector identity, and action readability. Those
checks do not replace a person playing the build; leave the A5 task packets
`in_progress` until the checklist below is performed and evidence is recorded.

Record the tester, date, build/commit, platform, result, and concise notes for
each failed or deferred item. Do not convert an unperformed item into a pass.

## Character Select and match launch

- [ ] Exactly Doge, Magic Orange Cat, and Salad Cat appear in the original P1
  and P2 selectors with recognizable names.
- [ ] P1 and P2 selected values remain obvious with every pairing, including a
  same-character match.
- [ ] `1P VS CPU` starts and can finish a match with the selected fighters.
- [ ] `2P LOCAL` starts and can finish a match with the selected fighters.
- [ ] Keyboard focus and all four launch buttons remain legible at the target
  desktop resolution.

## Doge gameplay and presentation

- [ ] Idle, walk, crouch, jump/fall/landing, guard/blockstun, hitstun, knockdown,
  get-up, throw, KO, and victory remain recognizable and visually stable.
- [ ] Light, Heavy, Low, air attack, throw, charge releases, Special, and
  Ultimate show the intended Doge poses without greybox fallback or bad pivots.
- [ ] Short, medium, and long Special charges feel distinct; releases near the
  24F and 54F boundaries select the expected level.
- [ ] Lv3 armor reads clearly on contact and Super Doge visibly replaces Heavy.
- [ ] Reset during charge, hit interruption, and active projectile/entity state
  returns to a clean starting position without stale visual effects.

## Training minimum

- [ ] `TRAINING LAB` starts with infinite-time training rules and both input
  histories visible.
- [ ] `R` resets HP, meter, positions, round state, charge, projectiles, and
  temporary entities.
- [ ] `G` cycles dummy guard through Off, Standing, and Crouching; Mid/High/Low
  outcomes match the displayed posture.
- [ ] `F1` toggles hitboxes and `F2` toggles frame/debug information without
  changing simulation outcomes.
- [ ] P1/P2 direction and L/H/G/S/U input display matches the keys actually held
  and pressed, including diagonals.

## Tutorial minimum

- [ ] `FIRST FIGHT` begins at movement and advances through Guard,
  Light + Heavy, Throw, Special, and Ultimate in that order.
- [ ] The Throw lesson accepts forward + Heavy after fighters have changed
  facing direction.
- [ ] Early or unrelated actions do not skip lessons or introduce extra topics.
- [ ] The Ultimate lesson can recognize the control without secretly granting
  meter, damage, or any other authoritative gameplay outcome.
- [ ] Prompts and completion feedback remain readable while both fighters and
  HUD are active.

## Sign-off

- Tester:
- Date:
- Build/commit:
- Platform:
- Result: pending
- Notes:
