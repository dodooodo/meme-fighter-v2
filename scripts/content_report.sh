#!/usr/bin/env bash
# Render the read-only character content report.
#
#   ./scripts/content_report.sh                     # print to stdout
#   ./scripts/content_report.sh --output report.md  # write to a file
#
# Exits non-zero when the index reports an error-severity issue.
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v godot >/dev/null 2>&1; then
  GODOT_BIN=godot
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN=godot4
else
  echo "Content report: NOT RUN — Godot executable unavailable" >&2
  exit 2
fi

exec "$GODOT_BIN" --headless --path . -s res://scripts/content_report.gd -- "$@"
