#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
"$ROOT/plugins/thinkbreak/bin/thinkbreak" init
if command -v codex >/dev/null 2>&1; then "$ROOT/scripts/install-codex-plugin.sh"; else echo "Codex CLI not found; skipped."; fi
if find_claude_cli >/dev/null 2>&1; then "$ROOT/scripts/install-claude-plugin.sh"; else echo "Claude Code CLI not found; skipped."; fi
printf 'Installed ThinkBreak Hooks and Skill. No app or browser extension was installed.\n'
