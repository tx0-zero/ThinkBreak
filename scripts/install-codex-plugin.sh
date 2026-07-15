#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/plugins/thinkbreak"

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI was not found. Install Codex, then run this script again." >&2
  exit 1
fi
"$PLUGIN/bin/thinkbreak" init
codex plugin marketplace remove thinkbreak >/dev/null 2>&1 || true
codex plugin marketplace add "$ROOT"
codex plugin add "thinkbreak@thinkbreak"
printf 'Installed ThinkBreak for Codex. Restart Codex or start a new task.\n'
