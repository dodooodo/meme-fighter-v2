# Meme Fighter V2 — Playable Beta

## Launch

Open `Meme Fighter V2.app`. The game starts at Character Select; choose both
fighters, then choose `1P VS CPU` or `2P LOCAL`.

### macOS first launch

This playable beta is not notarized with an Apple Developer distribution
certificate. If macOS blocks its first launch after download, Control-click
`Meme Fighter V2.app`, choose **Open**, then confirm **Open** in the macOS
dialog. This is a distribution-signing limitation only; the build does not
require the Godot editor.

## Controls

| Action | P1 | P2 Local |
| --- | --- | --- |
| Move / Jump | WASD | Arrow keys |
| Light / Heavy | U / I | M / , |
| Low | Down + U | Down + M |
| Throw | Forward + I | Forward + , |
| Guard | J | . |
| Special / Ultimate | K / L | / / ; |

Mirror matches are allowed. The selection screen shows the currently confirmed
P1 and P2 fighters before a match starts.

## After a Match

Press `R` for a rematch or `Esc` to return to Character Select.

## Status

Playable Beta build for macOS. Combat, roster, replay, snapshot, and
determinism validation passed before packaging.

Audio cue hooks are ready, but this build currently has no playable AudioStream
bank; it intentionally does not include fabricated audio assets.
