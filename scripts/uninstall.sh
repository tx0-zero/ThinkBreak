#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
PURGE_DATA=false
if [[ "${1:-}" == "--purge-data" || "${1:-}" == "--purge" ]]; then PURGE_DATA=true; fi

if command -v codex >/dev/null 2>&1; then
  codex plugin remove thinkbreak@thinkbreak >/dev/null 2>&1 || true
  codex plugin marketplace remove thinkbreak >/dev/null 2>&1 || true
fi
if find_claude_cli >/dev/null 2>&1; then
  run_claude_cli plugin uninstall --scope user thinkbreak@thinkbreak-local >/dev/null 2>&1 || true
  run_claude_cli plugin marketplace remove thinkbreak-local >/dev/null 2>&1 || true
fi

if [[ "$PURGE_DATA" == true ]]; then
  rm -rf "${THINKBREAK_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/thinkbreak}"
  printf 'Uninstalled ThinkBreak and removed local configuration and user Recipes.\n'
else
  printf 'Uninstalled ThinkBreak. Local configuration and user Recipes were preserved; use --purge-data to remove them.\n'
fi
