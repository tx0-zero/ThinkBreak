#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
run_claude_cli plugin validate "$ROOT/plugins/thinkbreak"
"$ROOT/plugins/thinkbreak/bin/thinkbreak" init
run_claude_cli plugin marketplace remove thinkbreak-local >/dev/null 2>&1 || true
run_claude_cli plugin marketplace add --scope user "$ROOT"
run_claude_cli plugin install --scope user thinkbreak@thinkbreak-local
printf 'Installed ThinkBreak for Claude Code. Restart Claude Code.\n'
