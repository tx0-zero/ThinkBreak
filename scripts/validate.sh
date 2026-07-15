#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
VERSION="$(thinkbreak_version "$ROOT")"
cd "$ROOT"

echo "== ThinkBreak $VERSION validation =="

bash -n scripts/*.sh plugins/thinkbreak/hooks/dispatch.sh plugins/thinkbreak/lib/*.sh plugins/thinkbreak/bin/thinkbreak tests/test_dispatch.sh
python3 - "$ROOT" "$VERSION" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
version = sys.argv[2]
assert re.fullmatch(r"\d+\.\d+\.\d+", version), version
for relative in (
    "plugins/thinkbreak/.codex-plugin/plugin.json",
    "plugins/thinkbreak/.claude-plugin/plugin.json",
):
    data = json.loads((root / relative).read_text())
    assert data["name"] == "thinkbreak", relative
    assert data["version"] == version, relative
for relative in (".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"):
    data = json.loads((root / relative).read_text())
    plugin = next(p for p in data["plugins"] if p["name"] == "thinkbreak")
    assert plugin["version"] == version, relative

hooks = json.loads((root / "plugins/thinkbreak/hooks/hooks.json").read_text())["hooks"]
assert set(hooks) == {"UserPromptSubmit", "PermissionRequest", "Stop"}
windows_hooks = json.loads((root / "plugins/thinkbreak/hooks/hooks.windows.json").read_text())["hooks"]
assert set(windows_hooks) == set(hooks)

for recipe in ("douyin-example", "tx0zero-entertainment", "custom-template"):
    directory = root / "plugins/thinkbreak/recipes" / recipe
    env = (directory / "recipe.env").read_text()
    assert f"RECIPE_ID={recipe}" in env
    assert (directory / "on-wait.sh").is_file()
    assert (directory / "on-wait.ps1").is_file()

for required in (
    "README.md", "README.en.md", "LICENSE", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SECURITY.md",
    "CHANGELOG.md", "plugins/thinkbreak/skills/thinkbreak/SKILL.md",
    "plugins/thinkbreak/hooks/dispatch.sh", "plugins/thinkbreak/hooks/dispatch.ps1",
    "plugins/thinkbreak/hooks/dispatch.cmd", "plugins/thinkbreak/hooks/hooks.windows.json",
    "plugins/thinkbreak/lib/runtime.sh", "plugins/thinkbreak/lib/runtime.ps1",
):
    assert (root / required).is_file(), required

# PowerShell reserves several automatic variable names. Using them as hook
# parameters makes the Windows dispatcher fail before it can handle an event.
for relative in ("plugins/thinkbreak/hooks/dispatch.ps1", "plugins/thinkbreak/lib/runtime.ps1", "plugins/thinkbreak/lib/platform-windows.ps1"):
    text = (root / relative).read_text()
    assert not re.search(r"\[string\]\$(?:Host|Pid|Event)\b", text, re.I), relative
windows_manifest = (root / "plugins/thinkbreak/hooks/hooks.windows.json").read_text()
assert "${CODEX_PLUGIN_ROOT" in windows_manifest
assert "dispatch.ps1" in windows_manifest
assert "powershell" in windows_manifest
print("Manifest, Hook, Recipe, Skill, and project-file checks passed.")
PY

./tests/test_dispatch.sh
printf 'PASS: all ThinkBreak validation checks\n'
