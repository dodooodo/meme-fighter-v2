# A-VS-004 — Golden Pair Game-Feel Pass

Implementation date: 2026-08-22. Scope: presentation-only combat feedback for
Salad Cat and Magic Orange Cat. Overall status: **COMPLETE WITH DEFERRED AUTHORED-ASSET GAPS**.

## Evidence status

- **Implementation:** automated feedback portion complete.
- **Automated verification:** complete for the final implementation and evidence
  diff: static validation 3650 passed / 0 failed, feedback tests 26 passed / 0
  failed, Golden Pair bindings 54 passed / 0 failed, stress tests 7 passed / 0
  failed, task-scope validation PASS, and the full project gate PASS.
- **Manual verification:** complete; the user reported the Golden Pair play
  checklist accepted on 2026-08-22. Per-item notes were not supplied.
- **Authored asset coverage:** incomplete for hit/guard SFX and Golden Pair
  Ultimate screen art. The user explicitly accepted both as deferred
  development fallbacks for this merge on 2026-08-22.

## Implemented feedback

One presentation-only `CombatFeedbackProfile` now owns the shared hierarchy
used by impact VFX, fighter hit flash/visual hold, camera impulse, screen white
flash, and named audio cues. Charged specials use the same special tier.

| Event | Automated result | Human/asset result |
| --- | --- | --- |
| Light → Heavy → Special → Ultimate | VFX, camera, and white flash increase monotonically | user checklist accepted |
| Block | blue burst, smaller flash/impulse, distinct tiered guard cue | readability accepted; authored SFX deferred |
| Throw | dedicated heavy burst/impulse/flash and cue | user checklist accepted |
| KO | strongest burst, camera impulse, white flash; existing KO overlay remains | user checklist accepted |
| Gameplay hitstop | unchanged; existing gameplay tests remain authoritative | perceived timing accepted |
| Ultimate body animation | direct Golden Pair binding from A-VS-003 | user checklist accepted |
| Ultimate screen | presenter foundation exists | **DEFERRED GAP:** no Golden Pair screen binding/art |
| Hit/guard sound | tiered cue IDs dispatch | **DEFERRED GAP:** no authored audio streams |

No gameplay data, hitstop, timing, damage, collision, snapshot, replay, or hash
state is modified by this pass.

## Human play checklist

Run from this worktree:

```bash
cd /Users/dodoodo/Projects/ahong/meme-fighter/meme-fighter-v2-a-vs-004
./play.sh
```

Select Salad Cat versus Magic Orange Cat and use VS CPU. Repeat with the
character order reversed. Record PASS/FAIL and a short note for each item:

1. `U` light impact is readable but clearly smallest.
2. `I` heavy feels stronger than light without obscuring the fighters.
3. `K` special has a clearly stronger burst, camera impulse, and flash.
4. `L` Ultimate (100 meter) is the strongest hit response.
5. Hold `J` to block: block feedback is visibly blue and weaker than a hit.
6. Hold `S+J` to crouch guard: low-block feedback remains distinguishable.
7. Reach KO: KO text, peak flash, and peak camera impulse are readable.
8. No flash remains stuck after round reset, retry, or returning to selection.
9. Report whether any flash is uncomfortable or any camera impulse causes
   motion discomfort.

The user accepted the checklist and explicitly accepted the two named authored
asset gaps as development fallbacks for this merge on 2026-08-22. Future asset
work must replace the fallback cue-only audio behavior and add a Golden Pair
Ultimate screen binding/art without claiming those assets exist today.
