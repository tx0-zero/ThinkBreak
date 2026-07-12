#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
PURGE_DATA=false
if [[ "${1:-}" == "--purge-data" ]]; then PURGE_DATA=true; fi

pkill -x ThinkBreak >/dev/null 2>&1 || true
rm -rf "$HOME/Applications/ThinkBreak.app"
rm -f "$HOME/.local/bin/thinkbreak-hook"

if command -v codex >/dev/null 2>&1; then
  codex plugin remove thinkbreak@thinkbreak >/dev/null 2>&1 || true
  codex plugin marketplace remove thinkbreak >/dev/null 2>&1 || true
fi
if run_claude_cli plugin list >/dev/null 2>&1; then
  run_claude_cli plugin uninstall --scope user thinkbreak@thinkbreak-local >/dev/null 2>&1 || true
  run_claude_cli plugin marketplace remove thinkbreak-local >/dev/null 2>&1 || true
fi

rm -f "$HOME/Library/Application Support/ThinkBreak/thinkbreak.sock"
if [[ "$PURGE_DATA" == true ]]; then
  rm -rf "$HOME/Library/Application Support/ThinkBreak"
  defaults delete com.tx0zero.ThinkBreak >/dev/null 2>&1 || true
  printf 'Uninstalled ThinkBreak and removed local settings.\n'
else
  printf 'Uninstalled ThinkBreak. Local settings were preserved; use --purge-data to remove them.\n'
fi
