#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREATOR="$HOME/.codex/skills/.system/plugin-creator/scripts/create_basic_plugin.py"
VALIDATOR="$HOME/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py"
DEST="$HOME/plugins/thinkbreak"

if [[ ! -f "$CREATOR" ]]; then
  echo "Codex plugin creator was not found at $CREATOR" >&2
  exit 1
fi

python3 "$CREATOR" thinkbreak --with-hooks --with-marketplace --category Productivity --force
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
ditto "$ROOT/plugin" "$DEST"
python3 "$VALIDATOR" "$DEST"

marketplace_name="$(python3 "$HOME/.codex/skills/.system/plugin-creator/scripts/read_marketplace_name.py")"
codex plugin add "thinkbreak@$marketplace_name"
printf 'Installed ThinkBreak for Codex. Start a new Codex task to load it.\n'
