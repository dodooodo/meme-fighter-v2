#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -ne 1 ]]; then
  echo "Usage: ./scripts/test_character.sh <character_id>" >&2
  exit 64
fi
cd "$(dirname "$0")/.."
if command -v godot >/dev/null 2>&1; then
  GODOT_BIN=godot
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN=godot4
else
  echo "Godot Runtime: NOT RUN — executable unavailable" >&2
  exit 2
fi
"$GODOT_BIN" --headless --path . --editor --quit
"$GODOT_BIN" --headless --path . -s res://scripts/test_character.gd -- "$1"
