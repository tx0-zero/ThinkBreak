#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
VERSION="$(thinkbreak_version "$ROOT")"
NAME="ThinkBreak-$VERSION"
STAGE="$ROOT/dist/$NAME"
ARCHIVE="$ROOT/dist/$NAME.zip"
rm -rf "$STAGE" "$ARCHIVE" "$ARCHIVE.sha256"
mkdir -p "$STAGE"
cp -R "$ROOT/plugins" "$ROOT/scripts" "$ROOT/.agents" "$ROOT/.claude-plugin" "$STAGE/"
cp -R "$ROOT/tests" "$STAGE/"
cp "$ROOT/README.md" "$ROOT/README.en.md" "$ROOT/LICENSE" "$ROOT/VERSION" "$ROOT/CHANGELOG.md" "$ROOT/CONTRIBUTING.md" "$ROOT/CODE_OF_CONDUCT.md" "$ROOT/SECURITY.md" "$STAGE/"
mkdir -p "$STAGE/docs/release-notes"
cp "$ROOT/docs/release-notes/v$VERSION.md" "$STAGE/docs/release-notes/"
(
  cd "$ROOT/dist"
  /usr/bin/zip -qry -X "$NAME.zip" "$NAME"
  shasum -a 256 "$NAME.zip" > "$NAME.zip.sha256"
)
printf 'Packaged %s\n' "$ARCHIVE"
