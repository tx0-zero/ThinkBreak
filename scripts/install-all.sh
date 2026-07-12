#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/install-app.sh"
"$ROOT/scripts/install-codex-plugin.sh"
"$ROOT/scripts/install-claude-plugin.sh"
