#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/plugins/thinkbreak"

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI was not found. Install or update Codex before installing the plugin." >&2
  exit 1
fi

# The marketplace stores its source path. Re-register it so installs remain portable
# when a clone or extracted release is moved to a different directory.
codex plugin marketplace remove thinkbreak >/dev/null 2>&1 || true
codex plugin marketplace add "$ROOT"
codex plugin add "thinkbreak@thinkbreak"
printf 'Installed ThinkBreak for Codex. Start a new Codex task to load it.\n'
