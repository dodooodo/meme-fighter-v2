#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_RUNTIME="$PROJECT_ROOT/../.godot_runtime/Godot.app/Contents/MacOS/Godot"

if [[ -x "$SHARED_RUNTIME" ]]; then
  GODOT_BIN="$SHARED_RUNTIME"
elif command -v godot >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot4)"
else
  echo "找不到 Godot。" >&2
  echo "預期共用 runtime 位於：$SHARED_RUNTIME" >&2
  exit 2
fi

COMMAND="${1:-play}"

case "$COMMAND" in
  play)
    exec "$GODOT_BIN" --path "$PROJECT_ROOT"
    ;;
  editor)
    exec "$GODOT_BIN" --editor --path "$PROJECT_ROOT"
    ;;
  test|tests)
    "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --editor --quit
    exec "$GODOT_BIN" --headless --path "$PROJECT_ROOT" -s res://tests/run_tests.gd
    ;;
  version)
    exec "$GODOT_BIN" --version
    ;;
  help|-h|--help)
    echo "用法："
    echo "  ./play.sh          直接啟動遊戲"
    echo "  ./play.sh editor   開啟 Godot 編輯器"
    echo "  ./play.sh test     匯入專案並執行完整 headless 測試"
    echo "  ./play.sh version  顯示使用中的 Godot 版本"
    ;;
  *)
    echo "未知指令：$COMMAND" >&2
    echo "請執行 ./play.sh help 查看用法。" >&2
    exit 2
    ;;
esac
