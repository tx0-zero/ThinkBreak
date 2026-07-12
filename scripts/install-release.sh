#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"

if [[ ! -d "$ROOT/ThinkBreak.app" || ! -x "$ROOT/bin/thinkbreak-hook" ]]; then
  echo "Run this script from the extracted ThinkBreak release package." >&2
  exit 1
fi
mkdir -p "$HOME/Applications" "$HOME/.local/bin"
pkill -x ThinkBreak >/dev/null 2>&1 || true
rm -rf "$HOME/Applications/ThinkBreak.app"
ditto "$ROOT/ThinkBreak.app" "$HOME/Applications/ThinkBreak.app"
cp "$ROOT/bin/thinkbreak-hook" "$HOME/.local/bin/thinkbreak-hook"
chmod +x "$HOME/.local/bin/thinkbreak-hook"
open -g -j "$HOME/Applications/ThinkBreak.app"

if command -v codex >/dev/null 2>&1; then
  codex plugin marketplace remove thinkbreak >/dev/null 2>&1 || true
  codex plugin marketplace add "$ROOT"
  codex plugin add thinkbreak@thinkbreak
else
  echo "Codex CLI not found; skipped Codex plugin installation." >&2
fi

if run_claude_cli plugin list >/dev/null 2>&1; then
  run_claude_cli plugin marketplace remove thinkbreak-local >/dev/null 2>&1 || true
  run_claude_cli plugin marketplace add --scope user "$ROOT"
  run_claude_cli plugin install --scope user thinkbreak@thinkbreak-local
else
  echo "Claude Code CLI not found; skipped Claude Code plugin installation." >&2
fi
printf 'Installed ThinkBreak release. Complete the permissions described in README.md.\n'
