#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh"
mkdir -p "$HOME/Applications" "$HOME/.local/bin"
if pgrep -x ThinkBreak >/dev/null 2>&1; then
  pkill -x ThinkBreak || true
  for _ in {1..20}; do
    pgrep -x ThinkBreak >/dev/null 2>&1 || break
    sleep 0.1
  done
fi
rm -rf "$HOME/Applications/ThinkBreak.app"
ditto "$ROOT/dist/ThinkBreak.app" "$HOME/Applications/ThinkBreak.app"
cp "$ROOT/.build/release/thinkbreak-hook" "$HOME/.local/bin/thinkbreak-hook"
chmod +x "$HOME/.local/bin/thinkbreak-hook"
open -g -j "$HOME/Applications/ThinkBreak.app"
printf 'Installed ThinkBreak.app and thinkbreak-hook.\n'
