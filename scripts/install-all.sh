#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"

"$ROOT/scripts/install-app.sh"

if command -v codex >/dev/null 2>&1; then
  "$ROOT/scripts/install-codex-plugin.sh"
else
  echo "Codex CLI not found; skipped Codex plugin installation." >&2
fi

if find_claude_cli >/dev/null 2>&1; then
  "$ROOT/scripts/install-claude-plugin.sh"
else
  echo "Claude Code CLI not found; skipped Claude Code plugin installation." >&2
fi
