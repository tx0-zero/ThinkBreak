<div align="center">
  <img src="assets/thinkbreak-icon.png" width="128" alt="ThinkBreak icon">
  <h1>ThinkBreak</h1>
  <p>Take a break while your AI is thinking.</p>
  <p><strong>A macOS waiting-content switcher for Codex and Claude Code</strong></p>
  <p>English · <a href="README.md">简体中文</a></p>
</div>

> [!WARNING]
> `v0.1.0` is an ad-hoc-signed, non-notarized beta. Read the first-launch and permission instructions before installing it.

ThinkBreak is an open-source macOS menu-bar app. After you submit a task to Codex or Claude Code, it waits two seconds by default and opens a web page of your choice if the task is still running. When the task completes or requests permission, ThinkBreak pauses page media and returns focus to the originating window.

Use Douyin, a novel, an article, or any regular web page as waiting content. Each preset keeps its own Chrome tab so login state, recommendation feeds, scroll position, and reading position can be reused.

![ThinkBreak settings](docs/images/settings.png)

## Features

- Master switch in both the menu and Settings.
- Editable, reorderable `media` and `reading` presets.
- Media mode resumes visible media on entry and pauses page audio/video on exit when Chrome permits it.
- Reading mode only opens and returns, leaving page state untouched.
- Two-second short-task guard to avoid flashing windows.
- Focus restoration on completion, permission request, or safety timeout.
- Newest-task foreground ownership prevents stale `Stop` events from stealing focus.
- Local-only settings and transient window identifiers; no telemetry or analytics SDK.

![ThinkBreak menu](docs/images/menu.png)

## The “Watch ads for Tokens” joke

This disabled switch is a joke inspired by community discussions about watching ads in exchange for AI tokens. `v0.1.0` displays no ads, connects to no account, performs no tracking, and grants or modifies no real tokens.

![Disabled ad joke switch](docs/images/ad-joke.png)

## Requirements

- macOS 14 Sonoma or later
- Google Chrome
- Codex App / Codex CLI and/or Claude Code
- macOS Accessibility permission for precise window restoration
- Chrome **Allow JavaScript from Apple Events** for media play/pause control

The first release supports macOS, Google Chrome, Codex App, and Claude Code running in a terminal.

## Install

### Download the beta

1. Download `ThinkBreak-0.1.0-macos.zip` and its `.sha256` file from GitHub Releases.
2. Optionally verify it:

   ```bash
   shasum -a 256 -c ThinkBreak-0.1.0-macos.zip.sha256
   ```

3. Extract the archive, open Terminal in that folder, and run:

   ```bash
   ./scripts/install-release.sh
   ```

The installer copies the app to `~/Applications/ThinkBreak.app`, installs `thinkbreak-hook` in `~/.local/bin`, and installs plugins for the available Codex and Claude Code CLIs.

### Build from source

Xcode Command Line Tools and Swift 6 are required:

```bash
git clone https://github.com/Tx0Zero/ThinkBreak.git
cd ThinkBreak
./scripts/install-all.sh
```

Individual installers are also available:

```bash
./scripts/install-app.sh
./scripts/install-codex-plugin.sh
./scripts/install-claude-plugin.sh
```

The Claude installer prefers the official `claude` command on `PATH`, then checks common global npm locations. Set `CLAUDE_CLI=/path/to/claude` for custom environments.

## First launch and permissions

### Open the non-notarized beta

The beta has no Apple Developer ID signature or notarization. If macOS blocks it, Control-click `~/Applications/ThinkBreak.app`, choose **Open**, then confirm **Open** again.

If quarantine still blocks an archive you trust:

```bash
xattr -dr com.apple.quarantine ~/Applications/ThinkBreak.app
open ~/Applications/ThinkBreak.app
```

### Accessibility

Open **System Settings → Privacy & Security → Accessibility** and allow ThinkBreak. This permission is used to capture and restore the original app, window, and focused control. Without it, hooks still exit immediately and never block Codex or Claude Code, but focus restoration may be incomplete.

### Chrome Apple Events JavaScript

Enable **View → Developer → Allow JavaScript from Apple Events** in Chrome. ThinkBreak uses it only to resume and pause page media. Without it, Chrome window and tab switching still works, but media control may fail. Use **Test Chrome** in Settings to verify the connection.

## Usage

1. Click the ThinkBreak menu-bar icon.
2. Enable automatic switching.
3. Open Settings and edit the default preset or add a web page.
4. Choose `media` for audio/video sites or `reading` for novels and articles.
5. Select the active preset and submit a Codex or Claude Code task as usual.

Each preset reuses its own tab. If that tab is closed manually, ThinkBreak recreates it the next time it is needed.

## Update and uninstall

For source installs:

```bash
git pull
./scripts/install-all.sh
```

For release installs, download the newer archive and run its installer again. Reinstallation preserves settings in `~/Library/Application Support/ThinkBreak/`.

Uninstall while preserving settings:

```bash
./scripts/uninstall.sh
```

Remove the local settings as well:

```bash
./scripts/uninstall.sh --purge-data
```

Uninstallation does not alter Chrome profiles, browsing history, logins, or ordinary tabs.

## Privacy

ThinkBreak has no telemetry, analytics SDK, ad SDK, or remote backend. Preset URLs, the selected profile, timing settings, and transient focus-restoration identifiers remain on your Mac. Hooks do not send prompt or task contents.

## Scope and limitations

`v0.1.0` does not automatically scroll feeds, choose videos, like, comment, follow, share, operate website accounts, display ads, track users, or grant real token rewards. Browser autoplay policies and site-specific players may prevent media control. Safari, Firefox, Windows, and Linux are not supported. The downloadable beta is not Apple-notarized.

## Troubleshooting

- **No switch:** confirm the master switch and active preset are enabled, the task lasts longer than the delay, and the app is running.
- **Media does not pause:** enable Chrome JavaScript from Apple Events and use **Test Chrome** in Settings.
- **Wrong window restored:** re-enable Accessibility permission and restart ThinkBreak.
- **Only one agent installed:** that is supported; run only the relevant plugin installer.

## Development

```bash
./scripts/validate.sh
./scripts/package-release.sh
```

The validation suite runs 18 core behavior checks plus Debug/Release builds, shell syntax checks, version synchronization checks, plugin manifest and Info.plist checks, and ad-hoc signature verification. Complete [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) before publishing a release.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contributions and [`SECURITY.md`](SECURITY.md) for private vulnerability reporting.

## License

[MIT License](LICENSE) © TX0Zero Studio

## Disclaimer

ThinkBreak is an independent open-source community project. It is not affiliated with, authorized by, sponsored by, or endorsed by OpenAI, Anthropic, Google, Google Chrome, Douyin, or their affiliates. Product names and trademarks belong to their respective owners.
