<div align="center">
  <img src="assets/thinkbreak-icon.png" width="128" alt="ThinkBreak icon">
  <h1>ThinkBreak</h1>
  <p>Your Agent is working. You can briefly leave the input box.</p>
  <p><strong>A Hook-first waiting-action Recipe</strong></p>
  <p>English · <a href="README.md">简体中文</a></p>
</div>

ThinkBreak is a lightweight lifecycle Hook convention and editable Recipe set for Codex, Claude Code, and similar Agents.

> Agent submits work → wait a few seconds → run your action → return when the Agent finishes or needs you.

It is not a desktop app, menu-bar process, Electron/Tauri client, browser extension, MCP server, or advertising platform. There is no resident process after installation.

## What it does

- Opens a webpage or runs your script after the default two-second delay.
- Cancels the waiting action for short tasks, avoiding flicker and focus changes.
- Runs `on-return` for `Stop` and `on-attention` for `PermissionRequest`.
- Best-effort restores the source application window without blocking the Agent.
- Gives the newest task foreground ownership so an older task cannot steal focus back.
- Cleans up after the default 30-minute safety timeout.
- Keeps the behavior in user-editable Recipes instead of hard-coding Douyin, Bilibili, novels, or a browser.

### Douyin example

The first built-in example opens Douyin:

```text
recipes/douyin-example/
└── RECIPE_WAIT_URL=https://www.douyin.com/
```

It opens the URL with the system default browser, so the browser naturally uses the login session you already have. ThinkBreak does not read cookies, passwords, tokens, or browser profiles, and it does not promise exact tab reuse or automatic media pausing. If you want media cleanup, put a reviewed local command in your own Recipe.

Douyin is only an example. Copy the template for Bilibili, a novel, music, articles, your own website, shortcuts, or any local action.

## Install

### macOS / Linux

```bash
git clone https://github.com/Tx0Zero/ThinkBreak.git
cd ThinkBreak
./scripts/install-all.sh
```

Install only one host if you prefer:

```bash
./scripts/install-codex-plugin.sh
./scripts/install-claude-plugin.sh
```

The installer creates local configuration, registers the selected Plugin, and installs the Hook + Skill. It does not install an app, change browser data, or start a background service.

### Windows

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\install-all.ps1
```

The Windows manifest is `plugins/thinkbreak/hooks/hooks.windows.json`. Put its commands in the user-level Codex or Claude Code Hook configuration, keeping the command pointed at `dispatch.ps1` in the same plugin directory. Windows does not need Bash, Swift, Electron, or a resident application.

## Configuration

The local configuration is a simple `key=value` file:

```text
ENABLED=true
RECIPE_ID=douyin-example
DELAY_SECONDS=2
SAFETY_TIMEOUT_SECONDS=1800
ACTION_TIMEOUT_SECONDS=4
```

The bundled Skill can manage this state. The CLI equivalents are:

```bash
plugins/thinkbreak/bin/thinkbreak status
plugins/thinkbreak/bin/thinkbreak enable
plugins/thinkbreak/bin/thinkbreak disable
plugins/thinkbreak/bin/thinkbreak use bilibili
plugins/thinkbreak/bin/thinkbreak set-delay 3
plugins/thinkbreak/bin/thinkbreak set-timeout 1800
plugins/thinkbreak/bin/thinkbreak validate
plugins/thinkbreak/bin/thinkbreak test
```

Ask Codex or Claude Code things like “open Bilibili while you work and return when done” or “disable ThinkBreak”. The Skill should show the exact URL and scripts before saving changes.

## Recipes

A Recipe directory contains:

```text
recipes/<recipe-id>/
├── recipe.env
├── on-wait.sh / on-wait.ps1
├── on-return.sh / on-return.ps1
├── on-attention.sh / on-attention.ps1
└── on-timeout.sh / on-timeout.ps1
```

Every script is optional. The Dispatcher owns generic source-window restoration, so a failing cleanup script cannot block the Agent.

Copy the template into your user Recipe directory and edit it:

```bash
mkdir -p ~/.config/thinkbreak/recipes/bilibili
cp plugins/thinkbreak/recipes/custom-template/* ~/.config/thinkbreak/recipes/bilibili/
sed -i.bak 's#custom-template#bilibili#g; s#https://example.com#https://www.bilibili.com/#' \
  ~/.config/thinkbreak/recipes/bilibili/recipe.env
plugins/thinkbreak/bin/thinkbreak use bilibili
plugins/thinkbreak/bin/thinkbreak validate
```

Available variables include `THINKBREAK_EVENT`, `THINKBREAK_HOST`, `THINKBREAK_SESSION_ID`, `THINKBREAK_PLATFORM`, `THINKBREAK_SOURCE_APP`, `THINKBREAK_SOURCE_WINDOW`, `THINKBREAK_RECIPE_ID`, `THINKBREAK_RECIPE_DIR`, `THINKBREAK_WAIT_URL`, and `THINKBREAK_HOME`.

Never put prompts, Agent output, project paths, cookies, passwords, access tokens, or browser profile paths into a Recipe. ThinkBreak passes lifecycle and source-window metadata only.

## “Watch ads for tokens” joke area

You can point a Recipe at your own website for an entertainment page, a project introduction, or interest collection around a future “watch ads for model credits” idea.

The current Core does not include an ad SDK, accounts, credits, a model relay, task uploads, automatic ads, or official OpenAI/Anthropic rewards. A future Relay, if ever built, should be a separate service and should not change the Hook or Recipe contract.

## Uninstall

```bash
./scripts/uninstall.sh
./scripts/uninstall.sh --purge-data
```

The default uninstall removes Plugin registration but preserves configuration and user Recipes. Windows users can run `scripts/uninstall.ps1` or `scripts/uninstall.ps1 -Purge`.

## Privacy and boundaries

ThinkBreak contains no telemetry, analytics SDK, advertising service, account system, or task-upload code. It does not read Agent prompts, replies, project files, cookies, or passwords. It does not like, comment, follow, scroll, turn pages, or simulate browsing behavior.

ThinkBreak is not affiliated with OpenAI, Anthropic, Google, Douyin, or Bilibili.

## Development

```bash
bash -n scripts/*.sh plugins/thinkbreak/hooks/dispatch.sh plugins/thinkbreak/lib/*.sh
./tests/test_dispatch.sh
./scripts/validate.sh
```

The test suite covers short-task cancellation, waiting, return, attention, task ownership, and safety timeout behavior.

## License

MIT License. Copyright TX0Zero Studio.
