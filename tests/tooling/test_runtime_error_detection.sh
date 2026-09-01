#!/usr/bin/env bash
# Phase 7 regression: an assertion-clean process with a Godot runtime error must fail verification.
set -euo pipefail
cd "$(dirname "$0")/../.."
if bash scripts/verify.sh --runtime-error-probe >/private/tmp/mf_runtime_error_probe.log 2>&1; then
  echo "[FAIL] verify.sh accepted an injected Godot runtime error" >&2
  exit 1
fi
rg -q -i 'Invalid call|SCRIPT ERROR' /private/tmp/mf_runtime_error_probe.log
echo "[PASS] verify.sh rejects injected Godot runtime errors"
