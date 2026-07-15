---
name: thinkbreak
description: Configure ThinkBreak Hook recipes for Codex or Claude Code. Use when the user wants an optional waiting action while an Agent works, such as opening Douyin, Bilibili, a novel, music, or a personal website.
---

# ThinkBreak

ThinkBreak is a Hook-first waiting recipe. It is not a desktop app, browser extension, MCP server, or content platform.

Use the installed ThinkBreak command from the plugin directory. On macOS/Linux it is `bin/thinkbreak`; on Windows use `bin/thinkbreak.ps1` through PowerShell.

## What to do

When the user asks to configure ThinkBreak:

1. Inspect the current state with `thinkbreak status`.
2. Explain the exact Recipe and scripts that will run.
3. Ask for confirmation before creating or changing a Recipe.
4. Prefer copying `recipes/custom-template` into the user's ThinkBreak recipe directory rather than modifying built-in files.
5. Set only the requested values; leave cleanup scripts empty unless the user explicitly asks for cleanup.
6. Run `thinkbreak validate` after a change.

## Common requests

- 开启：`thinkbreak enable`
- 关闭：`thinkbreak disable`
- 查看状态：`thinkbreak status`
- 选择 Recipe：`thinkbreak use <recipe-id>`
- 修改切出延迟：`thinkbreak set-delay <seconds>`
- 修改安全超时：`thinkbreak set-timeout <seconds>`
- 检查 Recipe：`thinkbreak validate`
- 运行一次测试：`thinkbreak test`
- 创建默认配置：`thinkbreak init`

## Recipe contract

A Recipe directory contains:

```text
recipe.env
on-wait.sh / on-wait.ps1
on-return.sh / on-return.ps1
on-attention.sh / on-attention.ps1
on-timeout.sh / on-timeout.ps1
```

Every script is optional. Missing scripts are no-ops. The Dispatcher always handles the generic source-window return; a cleanup script must not be required for focus restoration.

Available environment variables include:

```text
THINKBREAK_EVENT
THINKBREAK_HOST
THINKBREAK_SESSION_ID
THINKBREAK_PLATFORM
THINKBREAK_SOURCE_APP
THINKBREAK_SOURCE_WINDOW
THINKBREAK_RECIPE_ID
THINKBREAK_RECIPE_DIR
THINKBREAK_WAIT_URL
THINKBREAK_HOME
```

Never put Prompt text, Agent output, cookies, passwords, access tokens, or browser profile paths into a Recipe. Opening a normal browser URL uses the user's existing default browser session naturally; ThinkBreak does not read or copy login credentials.

## Examples

For “等待时打开 B 站，结束后直接回来”:

- copy `custom-template` to a new user Recipe, e.g. `bilibili`;
- set `RECIPE_WAIT_URL=https://www.bilibili.com/`;
- keep `on-return` empty unless the user explicitly wants a local cleanup command;
- select it with `thinkbreak use bilibili`;
- validate and show the final files.

For “跳出到我的网站”:

- create a Recipe with the user's exact URL;
- keep the Recipe disabled until the user confirms the URL;
- do not send Agent task data to the website.

The official `tx0zero-entertainment` Recipe is only a transparent URL sample. Its URL is empty and it is not selected by default. The “看广告换额度” idea is a joke/interest page concept only; do not implement advertising, account, rewards, or token relay behavior in ThinkBreak Core.
