# ThinkBreak Hook-first 重构实施计划

> 本计划基于 `docs/superpowers/specs/2026-07-15-thinkbreak-lightweight-plugin-architecture-design.md`。
> 目标是删除 Swift / App / Chrome 扩展路径，先交付一个由 Codex / Claude Code Hooks 驱动的 Recipe 系统。

## 1. 重构目标

最终仓库提供：

```text
Codex / Claude Code Plugin Hooks
        ↓
ThinkBreak Dispatcher
        ↓
用户选择的 Recipe
        ↓
打开网页、执行脚本或其他用户动作
        ↓
恢复 Agent 来源窗口
```

首版不提供：

- Swift 或 Swift Package；
- macOS 菜单栏应用；
- Windows 桌面应用；
- Electron / Tauri；
- Chrome 扩展；
- 常驻服务；
- 真实广告、账户或 Token 服务。

## 2. 阶段一：清理旧产品边界

### 目标

让仓库不再把 ThinkBreak 表述为 macOS 应用或浏览器控制器。

### 修改

- 更新 `README.md` 和 `README.en.md`：产品定义改为 Hook-first Recipe；
- 删除菜单栏、设置窗口、Chrome Apple Events、辅助功能作为必需能力的描述；
- 把“抖音”降级为可替换样板；
- 把“ThinkBreak 娱乐页”描述为用户明确选择的官方 Recipe；
- 明确网站 URL 在配置中可见、可替换、可关闭；
- 删除默认广告、Token、账户或遥测承诺；
- 更新 `CHANGELOG.md`，记录从 v0.1.0 App 版本到 v0.2.0 Hook-first 版本的边界变化；
- 更新 `docs/RELEASE_CHECKLIST.md`，移除 Apple 公证、菜单栏和 Chrome Apple Events 检查，新增 Recipe 和 Hook 检查。

### 验收

- README 不再要求安装 ThinkBreak.app；
- README 不再要求安装 Chrome 扩展；
- README 能用一句话解释“Agent 工作时执行你的 Hook，结束时执行返回动作”；
- 官方娱乐页没有隐藏 URL 或自动联网行为。

## 3. 阶段二：建立 Recipe 与配置格式

### 目标

让用户或 Agent 可以通过新增目录和脚本配置任意等待动作。

### 新目录

```text
recipes/
├── tx0zero-entertainment/
├── douyin-example/
└── custom-template/
```

### 文件

每个 Recipe 至少包含：

```text
recipe.env
on-wait.sh / on-wait.ps1
on-return.sh / on-return.ps1
on-attention.sh / on-attention.ps1
on-timeout.sh / on-timeout.ps1
```

脚本全部可选；缺失脚本表示 no-op。

### `recipe.env`

采用跨平台容易读取的 key-value 格式，不让 Dispatcher 依赖 jq、Node 或 Python：

```text
RECIPE_ID=tx0zero-entertainment
RECIPE_NAME=ThinkBreak 娱乐页
RECIPE_ENABLED=false
RECIPE_WAIT_URL=
```

URL 不写死在核心代码里。官方娱乐页 Recipe 在没有用户确认 URL 时保持禁用。

### 验收

- 非法 Recipe ID、路径穿越和缺失脚本被拒绝；
- Recipe 脚本不允许通过配置自动下载；
- 用户可复制 `custom-template` 创建新的 Recipe；
- Skill 可以只修改 Recipe，不改 Hook 清单。

## 4. 阶段三：实现跨平台 Dispatcher

### 目标

用短生命周期脚本完成延迟、取消、Session、Recipe 调用和来源窗口恢复。

### 文件

```text
plugins/thinkbreak/hooks/dispatch.sh
plugins/thinkbreak/hooks/dispatch.ps1
plugins/thinkbreak/lib/session.sh
plugins/thinkbreak/lib/session.ps1
plugins/thinkbreak/lib/platform-macos.sh
plugins/thinkbreak/lib/platform-windows.ps1
```

### 统一入口

```text
dispatch start <host> [session-id]
dispatch stop <host> [session-id]
dispatch attention <host> [session-id]
dispatch timeout <host> [session-id]
```

### `start`

1. 读取本地配置；
2. 总开关关闭时立即退出；
3. 生成或读取宿主 Session ID；
4. 捕获来源应用、进程和窗口标识；
5. 原子创建 Session 文件；
6. 启动 detached 延迟 Worker；
7. Hook 立即以成功状态退出。

### 延迟 Worker

1. 等待 `delay_seconds`；
2. 重新读取 Session；
3. 如果 Session 已结束、被更新或配置已关闭，退出；
4. 标记 Session 为 active；
5. 执行当前 Recipe 的 `on-wait`；
6. 写入当前前台所有者；
7. 等待安全超时；
8. 到期执行 timeout 流程。

### `stop` 与 `attention`

1. 原子标记 Session 结束；
2. 取消或让 Worker 自行退出；
3. 如果 Session 是当前前台所有者，执行对应 Recipe 清理脚本；
4. 在清理脚本超时或失败后，仍执行平台窗口恢复；
5. 删除 Session 和 Owner 文件；
6. Hook 正常退出。

### Session 存储

```text
macOS:  ~/.config/thinkbreak/sessions/
Windows: %APPDATA%\\ThinkBreak\\sessions\\
```

首版使用小文件和原子 rename；不引入数据库。

### 验收

- 两秒内 Stop 不执行 on-wait；
- Stop 不会阻塞 Hook 超过配置预算；
- attention 不等待安全延迟；
- 旧 Session 不清理新 Owner；
- Worker 异常退出不留下永久 Owner；
- 30 分钟安全超时可通过测试缩短；
- Recipe 失败仍恢复来源窗口。

## 5. 阶段四：平台动作

### macOS

实现：

- 获取当前前台应用和窗口元数据；
- 激活原应用；
- 尽力恢复原窗口；
- 使用 `open` 打开等待 URL；
- 可选执行用户提供的 AppleScript / Shortcut Recipe；
- 不把辅助功能权限作为 ThinkBreak 安装必需项。

如果 macOS 无法在无权限时获取准确窗口，则保存前台应用作为降级目标，并显示可操作诊断。

### Windows

实现：

- 获取当前前台 HWND、进程 ID 和窗口标题摘要；
- 使用 Win32 PowerShell 调用恢复窗口；
- 使用 `Start-Process` 打开等待 URL；
- 前台恢复被系统拒绝时闪烁任务栏，不循环抢焦点；
- 不使用 Cookie、浏览器 Profile 或 Chrome 内部 API。

### 媒体行为

首版不在 Core 中保证媒体暂停。

用户可以在 Recipe 的 `on-return` 中自行配置：

- macOS AppleScript；
- Windows 媒体键；
- PowerShell；
- 用户已有自动化工具；
- 其他本地命令。

文档中明确标注这是 Recipe 行为，不是 ThinkBreak Core 的通用保证。

## 6. 阶段五：Provider-specific Hooks

### Codex

- 保留 Codex 独立 Hook 清单；
- 读取 Codex 当前 Hook 输入格式；
- 将事件转换为 Dispatcher 的统一参数；
- 不依赖当前机器的个人路径；
- 安装后给出 Hook 信任检查提示。

### Claude Code

- 保留 Claude Code 独立 Hook 清单；
- 读取 stdin JSON 中可用的 Session 信息；
- 兼容没有 Session ID 时的宿主级 fallback；
- Hook stdout 不输出额外上下文；
- 命令失败时返回非阻塞状态。

### 共用约定

```text
THINKBREAK_EVENT
THINKBREAK_HOST
THINKBREAK_SESSION_ID
THINKBREAK_SOURCE_APP
THINKBREAK_SOURCE_WINDOW
```

事件中不包含 Prompt、回复和文件内容。

## 7. 阶段六：ThinkBreak Skill

### 目标

让 Agent 成为主要配置界面。

### Skill 必须支持

```text
开启 / 关闭 ThinkBreak
查看状态
选择 Recipe
新增网页 Recipe
复制自定义 Recipe 模板
修改延迟
修改安全超时
验证 Recipe
执行一次测试
恢复默认安全配置
```

### 生成规则

用户说：

```text
等待时打开 B 站，结束后直接回来
```

Skill 应：

1. 创建或复制 Recipe；
2. 写入 `on-wait`；
3. 保持 `on-return` 为空；
4. 保留 Dispatcher 的通用窗口恢复；
5. 展示将执行的命令；
6. 请求用户确认后保存；
7. 运行静态校验。

Skill 不应：

- 修改 Provider Hook 清单来添加站点逻辑；
- 读取 Cookie 或密码；
- 自动下载第三方脚本；
- 默认启用维护者网站；
- 把 Prompt 写入 Session 或日志。

## 8. 阶段七：官方娱乐 Recipe

### 内容

新增：

```text
recipes/tx0zero-entertainment/
```

默认禁用，直到安装时用户确认页面 URL。

页面内容由维护者网站负责：

- 娱乐内容；
- ThinkBreak 项目介绍；
- “未来看广告换模型额度”的兴趣收集；
- 明确说明当前没有 Token 奖励。

### Hook 行为

```text
on-wait:
    打开用户确认的页面 URL

on-return:
    no-op

on-attention:
    no-op
```

ThinkBreak 不向网站添加任务、Prompt、窗口或 Session 信息。

### 未来 Relay

未来如果用户量足够，独立开发 Relay 服务，不修改 Hook 合约。当前只保留普通 URL Recipe，不实现广告 SDK、账户、积分或中转 API。

## 9. 阶段八：安装与卸载

### 安装

- 从任意 clone 路径运行；
- 只复制 Plugin、Skill、Dispatcher 和 Recipes；
- 不安装应用；
- 不写入用户个人路径之外的开发者路径；
- 不自动启用官方娱乐 Recipe；
- 检测并清理重复 ThinkBreak Plugin 来源。

### 卸载

- 移除 Codex / Claude Code Hook 安装；
- 删除 ThinkBreak Plugin 文件；
- 默认保留用户配置和 Recipe；
- 提供显式 `--purge` 删除本地配置；
- 不修改 Chrome 用户数据。

## 10. 测试计划

### 静态检查

- Bash `bash -n`；
- PowerShell Parser；
- Recipe manifest 校验；
- 路径穿越校验；
- Hook 清单 JSON 校验；
- stdout 污染检查；
- shellcheck / PSScriptAnalyzer（若 CI 环境允许）。

### macOS

- 两秒取消；
- 长任务打开网址；
- Stop 恢复来源应用；
- attention 立即恢复；
- 多任务旧 Stop 不抢焦点；
- Worker 安全超时；
- 缺少辅助功能权限时不阻塞 Hook。

### Windows

- 两秒取消；
- 长任务打开网址；
- Stop 恢复 HWND；
- 前台切换失败时任务栏闪烁；
- PowerShell 脚本语法和路径包含空格时正常；
- 多任务旧 Stop 不抢焦点。

### Agent 配置

- Skill 可以创建 B 站 Recipe；
- Skill 可以创建小说 Recipe；
- Skill 可以创建维护者娱乐页 Recipe；
- Skill 可以关闭 ThinkBreak；
- Skill 可以验证和回滚 Recipe；
- Recipe 失败不阻塞 Agent。

## 11. 删除清单

在新 Hook-first 版本通过测试后删除：

```text
Package.swift
Sources/ThinkBreakApp/
Sources/ThinkBreakCore/
Sources/ThinkBreakHook/
Tests/ThinkBreakCoreTests/
scripts/build-app.sh
scripts/install-app.sh
scripts/package-release.sh 中的 .app 流程
assets/*.icns
旧菜单、设置、Chrome Apple Events 文档和截图
```

保留并重写：

```text
README.md
README.en.md
scripts/install-codex-plugin.sh
scripts/install-claude-plugin.sh
scripts/install-all.sh
scripts/uninstall.sh
plugins/thinkbreak/
```

## 12. 完成标准

- 仓库不再构建或发布 ThinkBreak.app；
- Codex 与 Claude Code 都只通过 Hooks 进入 Dispatcher；
- 用户只需安装插件，不需管理应用或扩展；
- 等待动作由 Recipe 决定，不由 Core 固化；
- 官方娱乐页是透明、可替换、默认关闭的 Recipe；
- 抖音只是样板，不是核心分支；
- ThinkBreak 不默认联网、不传任务内容、不读取凭证；
- 未来广告换额度可以作为普通网站 Recipe 或独立 Relay 接入；
- 所有失败都不能阻塞 Agent 的正常工作。
