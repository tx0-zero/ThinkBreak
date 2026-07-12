# ThinkBreak

ThinkBreak is a local macOS menu bar app plus Codex/Claude Code hook plugin. When an agent task runs longer than the configured delay, it switches to a dedicated Google Chrome window. When the task finishes or requests permission, it pauses media and restores the originating window.

## Install

```bash
./scripts/install-all.sh
```

The installer builds and launches `~/Applications/ThinkBreak.app`, installs the hook bridge at `~/.local/bin/thinkbreak-hook`, and installs the local plugin for Codex and Claude Code.

## First-run permissions (required)

ThinkBreak needs two one-time local permissions. Hooks continue to exit normally if either permission is missing, but automatic media control or precise window restoration will not work until setup is complete.

1. Open the ThinkBreak menu bar icon and choose **设置…**.
2. Click **授予辅助功能权限**.
3. In **System Settings → Privacy & Security → Accessibility**, enable **ThinkBreak**. This lets ThinkBreak return to the exact Codex or terminal window and restore its input focus.
4. In Google Chrome choose **View → Developer → Allow JavaScript from Apple Events**. This lets ThinkBreak resume visible media when entering a `media` profile and pause page media when returning.
5. Back in ThinkBreak settings, click **立即打开**, then **测试 Chrome**. The status should say **Chrome 脚本控制正常。**
6. Start a new Codex task and restart Claude Code so their plugin caches include ThinkBreak.

ThinkBreak does not request browser passwords, browsing history, or cloud access. Profile URLs and runtime state remain in `~/Library/Application Support/ThinkBreak/`.

### If automatic return or pause does not work

- Reopen **System Settings → Privacy & Security → Accessibility** and confirm the installed `~/Applications/ThinkBreak.app` is enabled.
- Confirm Chrome still has **View → Developer → Allow JavaScript from Apple Events** checked; Chrome updates or profile changes may require checking it again.
- Open ThinkBreak settings and run **测试 Chrome** before testing a long agent task.
- Restart ThinkBreak from the menu bar, then start a new Codex task or restart Claude Code after installing or updating the plugin.

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
