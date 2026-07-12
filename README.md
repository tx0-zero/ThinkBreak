# ThinkBreak

ThinkBreak is a local macOS menu bar app plus Codex/Claude Code hook plugin. When an agent task runs longer than the configured delay, it switches to a dedicated Google Chrome window. When the task finishes or requests permission, it pauses media and restores the originating window.

## Install

```bash
./scripts/install-all.sh
```

The installer builds and launches `~/Applications/ThinkBreak.app`, installs the hook bridge at `~/.local/bin/thinkbreak-hook`, and installs the local plugin for Codex and Claude Code.

## First-run setup

1. Open the ThinkBreak menu bar icon and choose **设置**.
2. Grant Accessibility permission when prompted.
3. In Chrome choose **View → Developer → Allow JavaScript from Apple Events**.
4. In ThinkBreak settings choose **立即打开**, then **测试 Chrome**.
5. Start a new Codex task and restart Claude Code so their plugin caches include ThinkBreak.

## Content profiles

Profiles are edited in the settings window and stored locally at:

`~/Library/Application Support/ThinkBreak/settings.json`

- **视频 / 音频**: resumes visible HTML media on entry and pauses all media on exit.
- **阅读**: preserves the page and scroll position without changing playback.

ThinkBreak keeps one dedicated Chrome window and reuses a tab for each profile. It never likes, follows, comments, or scrolls automatically.

## Development

```bash
swift run ThinkBreakTests
swift build
./scripts/build-app.sh
```
