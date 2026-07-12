#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
VERSION="$(thinkbreak_version "$ROOT")"

python3 - "$ROOT" "$VERSION" <<'PY'
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
version = sys.argv[2]
for relative in (
    'plugins/thinkbreak/.codex-plugin/plugin.json',
    'plugins/thinkbreak/.claude-plugin/plugin.json',
):
    path = root / relative
    data = json.loads(path.read_text())
    data['version'] = version
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
for relative in ('.claude-plugin/marketplace.json', '.agents/plugins/marketplace.json'):
    marketplace = root / relative
    data = json.loads(marketplace.read_text())
    for plugin in data.get('plugins', []):
        if plugin.get('name') == 'thinkbreak':
            plugin['version'] = version
    marketplace.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY

printf 'Synchronized ThinkBreak version %s.\n' "$VERSION"
