#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
VERSION="$(thinkbreak_version "$ROOT")"
NAME="ThinkBreak-$VERSION-macos"
STAGE="$ROOT/dist/$NAME"
ARCHIVE="$ROOT/dist/$NAME.zip"

"$ROOT/scripts/build-app.sh"
rm -rf "$STAGE" "$ARCHIVE" "$ARCHIVE.sha256"
mkdir -p "$STAGE/bin" "$STAGE/plugins" "$STAGE/scripts" "$STAGE/.agents/plugins" "$STAGE/.claude-plugin" "$STAGE/assets" "$STAGE/docs/images"
ditto "$ROOT/dist/ThinkBreak.app" "$STAGE/ThinkBreak.app"
cp "$ROOT/.build/release/thinkbreak-hook" "$STAGE/bin/thinkbreak-hook"
ditto "$ROOT/plugins/thinkbreak" "$STAGE/plugins/thinkbreak"
cp "$ROOT/.agents/plugins/marketplace.json" "$STAGE/.agents/plugins/marketplace.json"
cp "$ROOT/.claude-plugin/marketplace.json" "$STAGE/.claude-plugin/marketplace.json"
cp "$ROOT/scripts/common.sh" "$ROOT/scripts/install-release.sh" "$ROOT/scripts/uninstall.sh" "$STAGE/scripts/"
cp "$ROOT/README.md" "$ROOT/README.en.md" "$ROOT/LICENSE" "$ROOT/VERSION" "$STAGE/"
cp "$ROOT/assets/thinkbreak-icon.png" "$STAGE/assets/"
cp "$ROOT/docs/images/"*.png "$STAGE/docs/images/"
(
  cd "$ROOT/dist"
  /usr/bin/zip -qry -X "$NAME.zip" "$NAME"
  shasum -a 256 "$NAME.zip" > "$NAME.zip.sha256"
)
printf 'Packaged %s\n' "$ARCHIVE"
