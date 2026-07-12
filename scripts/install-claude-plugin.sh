#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_CLI="$HOME/.local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
if [[ ! -f "$CLAUDE_CLI" ]]; then
  echo "Claude Code CLI was not found at $CLAUDE_CLI" >&2
  exit 1
fi

node "$CLAUDE_CLI" plugin validate "$ROOT/plugin"
if ! node "$CLAUDE_CLI" plugin marketplace list | grep -q 'thinkbreak-local'; then
  node "$CLAUDE_CLI" plugin marketplace add --scope user "$ROOT"
else
  node "$CLAUDE_CLI" plugin marketplace update thinkbreak-local
fi
node "$CLAUDE_CLI" plugin install --scope user thinkbreak@thinkbreak-local
printf 'Installed ThinkBreak for Claude Code. Restart Claude Code to load it.\n'
