#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
VERSION="$(thinkbreak_version "$ROOT")"
cd "$ROOT"

echo "== ThinkBreak $VERSION validation =="

bash -n scripts/*.sh plugins/thinkbreak/hooks/dispatch.sh
swift run ThinkBreakTests
swift build
swift build -c release
"$ROOT/scripts/build-app.sh"

plutil -lint "$ROOT/dist/ThinkBreak.app/Contents/Info.plist"
codesign --verify --deep --strict "$ROOT/dist/ThinkBreak.app"

python3 - "$ROOT" "$VERSION" <<'PY'
import json
import plistlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
version = sys.argv[2]
required = {
    "plugins/thinkbreak/.codex-plugin/plugin.json": version,
    "plugins/thinkbreak/.claude-plugin/plugin.json": version,
}
for relative, expected in required.items():
    data = json.loads((root / relative).read_text())
    assert data.get("name") == "thinkbreak", f"unexpected plugin name in {relative}"
    assert data.get("version") == expected, f"version mismatch in {relative}"

claude_market = json.loads((root / ".claude-plugin/marketplace.json").read_text())
claude = next(p for p in claude_market["plugins"] if p["name"] == "thinkbreak")
assert claude["version"] == version, "Claude marketplace version mismatch"
assert claude["source"] == "./plugins/thinkbreak", "Claude marketplace source mismatch"

codex_market = json.loads((root / ".agents/plugins/marketplace.json").read_text())
codex = next(p for p in codex_market["plugins"] if p["name"] == "thinkbreak")
assert codex["version"] == version, "Codex marketplace version mismatch"
assert codex["source"]["path"] == "./plugins/thinkbreak", "Codex marketplace source mismatch"

hooks = json.loads((root / "plugins/thinkbreak/hooks/hooks.json").read_text())["hooks"]
assert set(hooks) == {"UserPromptSubmit", "PermissionRequest", "Stop"}, "hook events changed"

with (root / "dist/ThinkBreak.app/Contents/Info.plist").open("rb") as f:
    plist = plistlib.load(f)
assert plist["CFBundleShortVersionString"] == version, "app version mismatch"
assert plist["LSMinimumSystemVersion"] == "14.0", "minimum macOS version mismatch"

required_files = [
    "README.md", "README.en.md", "LICENSE", "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md", "SECURITY.md", "CHANGELOG.md",
    "assets/ThinkBreak.icns", "docs/images/menu.png",
    "docs/images/settings.png", "docs/images/ad-joke.png",
]
for relative in required_files:
    assert (root / relative).is_file(), f"missing required file: {relative}"
print("Manifest, version, plist, hook, and project-file checks passed.")
PY

if [[ -n "${CLAUDE_CLI:-}" ]] || command -v claude >/dev/null 2>&1; then
  if run_claude_cli plugin validate "$ROOT/plugins/thinkbreak"; then
    echo "Claude plugin validation passed."
  else
    echo "Claude plugin validation failed." >&2
    exit 1
  fi
else
  echo "Claude CLI not found; skipped optional official Claude plugin validation."
fi

echo "PASS: all ThinkBreak validation checks"
