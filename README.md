<div align="center">
  <img src="assets/thinkbreak-icon.png" width="128" alt="ThinkBreak 图标">
  <h1>ThinkBreak</h1>
  <p>Agent 在工作，你可以短暂离开输入框。</p>
  <p><strong>一个 Hook-first 的等待动作 Recipe</strong></p>
  <p><a href="README.en.md">English</a> · 简体中文</p>
</div>

ThinkBreak 是给 Codex、Claude Code 等 Agent 使用的一套轻量 Hook 思路和可替换 Recipe。

> Agent 提交任务 → 等待几秒 → 执行你定义的动作 → Agent 完成或需要你时返回。

它不是桌面应用、菜单栏程序、Electron/Tauri 客户端、浏览器扩展、MCP 服务或广告平台。安装后没有常驻进程；Hooks 只在 Agent 生命周期事件发生时短暂运行。

## 能做什么

- 任务超过默认 2 秒后打开一个网页，或执行你自己的脚本。
- 任务很快完成时取消等待动作，不闪屏、不切换焦点。
- `Stop` 时执行 `on-return`，`PermissionRequest` 时执行 `on-attention`。
- 通用地恢复任务开始前的来源应用窗口；恢复失败不会阻塞 Agent。
- 最新任务拥有前台控制权，旧任务结束不会抢走新任务的焦点。
- 等待达到安全时限后自动清理并返回，默认 30 分钟。
- 所有动作由用户可编辑的 Recipe 决定，不把 B 站、抖音、小说或某个浏览器固化进核心。

### 抖音样板

首个内置样板是抖音：

```text
recipes/douyin-example/
└── RECIPE_WAIT_URL=https://www.douyin.com/
```

它通过系统默认浏览器打开抖音，因此会自然使用你已经登录的浏览器会话。ThinkBreak 不读取 Cookie、密码、Token 或浏览器 Profile，也不承诺精确复用某个标签页或自动暂停视频。需要媒体暂停时，请在自己的 Recipe 中配置本机脚本。

抖音只是一份样板。你可以复制模板改成 B 站、小说、音乐、文章、自己的网站、快捷指令或任意本地动作。

## 安装

### macOS / Linux

```bash
git clone https://github.com/tx0-zero/ThinkBreak.git
cd ThinkBreak
./scripts/install-all.sh
```

也可以只安装一个宿主：

```bash
./scripts/install-codex-plugin.sh
./scripts/install-claude-plugin.sh
```

安装脚本会：

1. 创建本地配置：`~/.config/thinkbreak/config.env`；
2. 注册对应的 Codex / Claude Code 本地 Plugin；
3. 保留 Hook 和 Skill；
4. 不安装应用、不修改浏览器数据、不启动后台服务。

如果某个 CLI 尚未安装，统一安装脚本会跳过它并给出提示。安装官方 Claude Code 时，脚本会优先寻找 `claude` 命令，再检查常见 npm 安装位置；也可以通过 `CLAUDE_CLI` 指定路径。

### Windows

Windows 使用 PowerShell Dispatcher：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\install-all.ps1
```

Windows Hook 清单位于：

```text
plugins/thinkbreak/hooks/hooks.windows.json
```

把其中的 Hook 配置放入 Codex 或 Claude Code 的用户级 Hook 配置，并保持命令指向同目录的 `dispatch.ps1`。Windows 不需要 Bash、Swift、Electron 或常驻应用。

## 配置

配置文件是简单的 `key=value` 文本：

```text
ENABLED=true
RECIPE_ID=douyin-example
DELAY_SECONDS=2
SAFETY_TIMEOUT_SECONDS=1800
ACTION_TIMEOUT_SECONDS=4
```

也可以让 ThinkBreak Skill 修改配置：

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

在 Claude Code 或 Codex 中直接说：

- “等待时打开 B 站，结束后直接回来。”
- “把等待内容换成我的小说网站。”
- “关闭 ThinkBreak。”
- “复制一个 Recipe，让等待时打开我的网站。”

Skill 应该先展示将执行的脚本和 URL，再请求确认。它只修改 Recipe，不修改宿主 Hook 来固化站点逻辑。

## Recipe：把等待内容留给用户

一个 Recipe 目录包含：

```text
recipes/<recipe-id>/
├── recipe.env
├── on-wait.sh       # macOS / Linux，可选
├── on-return.sh     # macOS / Linux，可选
├── on-attention.sh  # macOS / Linux，可选
├── on-timeout.sh    # macOS / Linux，可选
├── on-wait.ps1      # Windows，可选
├── on-return.ps1
├── on-attention.ps1
└── on-timeout.ps1
```

脚本缺失就是 no-op。Dispatcher 自己负责返回来源窗口，所以 `on-return` 失败也不会卡住 Agent。

创建自定义 Recipe：

```bash
mkdir -p ~/.config/thinkbreak/recipes/bilibili
cp plugins/thinkbreak/recipes/custom-template/* ~/.config/thinkbreak/recipes/bilibili/
sed -i.bak 's#custom-template#bilibili#g; s#https://example.com#https://www.bilibili.com/#' \
  ~/.config/thinkbreak/recipes/bilibili/recipe.env
plugins/thinkbreak/bin/thinkbreak use bilibili
plugins/thinkbreak/bin/thinkbreak validate
```

Recipe 脚本可以使用：

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

不要把 Prompt、回复、项目路径、Cookie、密码、访问 Token 或浏览器 Profile 写入 Recipe。ThinkBreak 只传递生命周期和来源窗口信息。

## Hook 生命周期

ThinkBreak 将宿主事件归一为：

| 宿主事件 | ThinkBreak 事件 | 行为 |
| --- | --- | --- |
| `UserPromptSubmit` | `start` | 记录来源窗口，启动延迟 Worker |
| `PermissionRequest` | `attention` | 立即清理等待动作并返回 |
| `Stop` | `stop` | 执行返回 Recipe 并恢复来源窗口 |

延迟 Worker、Session 文件和 Owner 文件都保存在本机：

- macOS / Linux：`~/.config/thinkbreak/`
- Windows：`%APPDATA%\ThinkBreak\`

Hooks 无论 Recipe 失败、权限缺失或浏览器没有启动，都会以非阻塞方式结束，不影响 Agent 正常工作。

## “看广告换 Token”玩梗区

项目保留这个想法作为一个透明的娱乐页面入口：你可以把 `RECIPE_WAIT_URL` 填成自己的网站，网站上放项目介绍，或者收集用户对未来“看广告换模型额度”的兴趣。

当前 ThinkBreak Core：

- 不接入广告 SDK；
- 不创建账户、积分或 Token 余额；
- 不连接模型中转服务；
- 不上传任务信息；
- 不自动显示广告；
- 不承诺 OpenAI、Anthropic 或其他平台的官方额度奖励。

未来若真的建设 Relay，应作为独立服务实现，不改变 Hook 和 Recipe 合约。

## 卸载

```bash
./scripts/uninstall.sh
```

默认只移除 Plugin 注册，保留配置和自定义 Recipe。确认要删除本地数据时：

```bash
./scripts/uninstall.sh --purge-data
```

Windows：

```powershell
.\scripts\uninstall.ps1
.\scripts\uninstall.ps1 -Purge
```

卸载不会删除 Codex、Claude Code 或浏览器数据。

## 隐私与边界

ThinkBreak 不包含遥测、分析 SDK、广告服务、账户系统或任务上传逻辑。它不读取 Agent Prompt、回复、项目文件、Cookie 或密码。网页是否使用登录状态由用户自己的浏览器负责。

ThinkBreak 也不自动点赞、评论、关注、刷视频、滚动、翻页或模拟用户行为。任何第三方网页动作都必须由用户自己审查并放进自己的 Recipe。

本项目与 OpenAI、Anthropic、Google、抖音、B 站没有官方隶属关系。

## 开发与测试

```bash
bash -n scripts/*.sh plugins/thinkbreak/hooks/dispatch.sh plugins/thinkbreak/lib/*.sh
./tests/test_dispatch.sh
./scripts/validate.sh
```

测试覆盖短任务取消、长任务等待、正常返回、授权返回、多任务前台所有权和安全超时。

## 许可证

MIT License，版权归 TX0Zero Studio。
