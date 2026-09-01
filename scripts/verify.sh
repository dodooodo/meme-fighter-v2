#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

runtime_error_pattern='SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid get|Invalid property'

run_godot_checked() {
  local log_file
  log_file="$(mktemp -t meme_fighter_godot.XXXXXX.log)"
  set +e
  "$GODOT_BIN" "$@" --log-file "$log_file"
  local status=$?
  set -e
  if rg -n -i "$runtime_error_pattern" "$log_file"; then
    echo "Godot runtime error detected; refusing a passing assertion-only result." >&2
    rm -f "$log_file"
    return 1
  fi
  rm -f "$log_file"
  return "$status"
}

if [[ "${1:-}" == "--runtime-error-probe" ]]; then
  GODOT_BIN="${GODOT_BIN:-godot}"
  run_godot_checked --headless --path . --script res://tests/tooling/runtime_error_probe.gd
  exit $?
fi

echo "Verification: static validation"
python3 scripts/static_validate.py
if command -v godot >/dev/null 2>&1; then
  GODOT_BIN=godot
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN=godot4
else
  echo "Godot Runtime: NOT RUN — executable unavailable" >&2
  exit 2
fi
echo "Verification: Godot version"
"$GODOT_BIN" --version
echo "Verification: Godot editor import"
run_godot_checked --headless --path . --editor --quit
echo "Verification: Godot runtime tests"
run_godot_checked --headless --path . -s res://tests/run_tests.gd
echo "Verification: character validation"
run_godot_checked --headless --path . -s res://scripts/validate_characters.gd
echo "Verification: character content index"
run_godot_checked --headless --path . -s res://scripts/content_report.gd -- --issues-only
