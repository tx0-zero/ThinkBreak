#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
VERSION="$(thinkbreak_version "$ROOT")"
cd "$ROOT"

swift build -c release
APP="$ROOT/dist/ThinkBreak.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/ThinkBreak" "$APP/Contents/MacOS/ThinkBreak"
if [[ -f "$ROOT/assets/ThinkBreak.icns" ]]; then
  cp "$ROOT/assets/ThinkBreak.icns" "$APP/Contents/Resources/ThinkBreak.icns"
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>CFBundleExecutable</key><string>ThinkBreak</string>
  <key>CFBundleIdentifier</key><string>com.tx0zero.ThinkBreak</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>ThinkBreak</string>
  <key>CFBundleDisplayName</key><string>ThinkBreak</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>ThinkBreak</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>ThinkBreak controls its dedicated Chrome window to open and pause waiting content.</string>
  <key>NSAccessibilityUsageDescription</key><string>ThinkBreak restores focus to the Codex or Claude Code window that started the task.</string>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$APP"
printf 'Built %s (%s)\n' "$APP" "$VERSION"
