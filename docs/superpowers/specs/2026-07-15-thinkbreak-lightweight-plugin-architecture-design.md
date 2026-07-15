# ThinkBreak Hook-first 架构设计

日期：2026-07-16

状态：已获方向确认，实施中
目标宿主：Codex、Claude Code
目标平台：macOS、Windows

## 1. 核心定义

ThinkBreak 不是桌面应用、浏览器扩展或内容平台。

ThinkBreak 是一套面向 Agent 的等待生命周期 Hook 约定，以及一个帮助 Agent 配置这些 Hook 的 Skill。

它只解决一件事：

> Agent 工作时执行用户定义的等待动作；Agent 完成或需要用户时执行返回动作。

抖音、B 站、小说、音乐、用户网站和未来的广告换额度页面，都只是可替换的 Recipe。ThinkBreak Core 不内置站点专属逻辑，也不要求所有用户安装同一种浏览器扩展。

## 2. 为什么不需要应用和扩展

### 2.1 不需要独立应用

用户通过 Codex 或 Claude Code 配置 ThinkBreak。Hook 调用短生命周期 Dispatcher，Dispatcher 在需要时启动一个延迟 Worker，任务结束后退出。

没有：

- 菜单栏应用；
- 托盘；
- SwiftUI、Electron 或 Tauri；
- 常驻后台服务；
- 独立设置窗口；
- 独立账户。

用户看到的是 Agent Skill、Hook 配置和用户自己选择的网页或脚本。

### 2.2 不需要浏览器扩展

Hook Recipe 默认只使用操作系统可以调用的能力：

- 打开 URL；
- 启动或激活用户指定的应用；
- 调用用户自己的脚本、快捷指令或 PowerShell；
- 任务结束后恢复来源窗口；
- 在平台允许时执行尽力而为的媒体暂停。

ThinkBreak 不承诺：

- 精确复用某一个 Chrome 标签页；
- 精确绑定某个 Chrome Profile；
- 只暂停某个网页标签；
- 读取或操作浏览器内部登录状态。

如果某个用户确实需要这些能力，可以让自己的 Agent 额外生成浏览器扩展、AppleScript、PowerShell、Playwright 或其他自动化方案。那属于用户自己的 Recipe，不属于 ThinkBreak Core。

## 3. Hooks 能力与边界

### 3.1 统一事件

ThinkBreak 将 Codex 与 Claude Code 的宿主事件归一为：

```text
start       用户提交任务
stop        Agent 完成任务
attention   Agent 等待用户授权或处理
```

可选内部事件：

```text
cancel      延迟期间任务已结束
 timeout    等待动作达到安全时限
```

Hook 只传事件、宿主、Session ID 和来源窗口元数据，不传 Prompt、回复、项目文件或任务内容。

### 3.2 Hook 可以做什么

Hook Dispatcher 可以：

- 记录前台来源应用和窗口；
- 创建 Session 文件；
- 启动两秒延迟 Worker；
- 取消尚未执行的等待动作；
- 执行当前 Recipe 的 `on-wait`；
- 执行 `on-return` 或 `on-attention`；
- 恢复来源窗口；
- 在安全超时后清理；
- 写入本地诊断日志；
- 在用户关闭总开关时跳过 Recipe。

### 3.3 Hook 不负责什么

Hook 不负责：

- 理解用户 Prompt；
- 在运行时调用 Agent；
- 判断用户应该看什么；
- 读取 Cookie、密码或 Token；
- 保证第三方网页的内部行为；
- 伪装成系统广告；
- 把用户任务数据上传到 ThinkBreak 网站。

## 4. 总体结构

```text
Codex / Claude Code
        │
 Provider-specific Hooks
        │
 normalize event + source context
        │
 ThinkBreak Dispatcher
        │
 ┌──────┴──────────┐
 Session files   User Recipe
                 ├── on-wait
                 ├── on-return
                 ├── on-attention
                 └── on-timeout
```

运行流程：

```text
UserPromptSubmit
    ↓
Dispatcher 捕获来源窗口
    ↓
写入 Session
    ↓
启动延迟 Worker，Hook 立即退出
    ↓
延迟结束且 Session 仍有效
    ↓
执行当前 Recipe/on-wait

Stop / PermissionRequest
    ↓
取消 Worker 或执行 Recipe/on-return
    ↓
恢复来源窗口
    ↓
清理 Session
```

## 5. 实现形态

第一版不要求编译桌面应用。使用宿主可执行的脚本和一个可选的短命令工具：

```text
plugins/thinkbreak/
├── hooks/
│   ├── hooks.json
│   ├── dispatch.sh
│   └── dispatch.ps1
├── skill/
│   └── SKILL.md
├── recipes/
│   ├── tx0zero-entertainment/
│   ├── douyin-example/
│   └── custom-template/
└── lib/
    ├── session.sh
    ├── session.ps1
    ├── platform-macos.sh
    └── platform-windows.ps1
```

如果 Shell / PowerShell 无法稳定完成某个平台的窗口捕获和恢复，再增加一个无界面的 `thinkbreak-dispatch` 小型跨平台二进制。它仍然只是 Hook 依赖，不是用户需要管理的应用。

## 6. Recipe 合约

### 6.1 目录结构

```text
recipes/<recipe-id>/
├── recipe.json
├── on-wait.sh       # macOS / Unix，可选
├── on-return.sh     # macOS / Unix，可选
├── on-attention.sh  # macOS / Unix，可选
├── on-timeout.sh    # macOS / Unix，可选
├── on-wait.ps1      # Windows，可选
├── on-return.ps1    # Windows，可选
├── on-attention.ps1 # Windows，可选
└── on-timeout.ps1   # Windows，可选
```

### 6.2 Manifest

```json
{
  "schema_version": 1,
  "id": "tx0zero-entertainment",
  "name": "ThinkBreak 娱乐页",
  "description": "Agent 工作时打开 ThinkBreak 官方娱乐页面",
  "enabled": false,
  "entry": "on-wait",
  "url": "https://example.com/thinkbreak"
}
```

`url` 只是样板配置，正式地址由用户在安装时确认或由 Agent 写入。仓库不能隐藏或强制跳转到维护者网站。

### 6.3 脚本环境

Recipe 脚本获得以下环境变量：

```text
THINKBREAK_EVENT=start|stop|attention|timeout
THINKBREAK_HOST=codex|claude-code
THINKBREAK_SESSION_ID=<opaque local id>
THINKBREAK_PLATFORM=macos|windows
THINKBREAK_SOURCE_APP=<best effort>
THINKBREAK_SOURCE_WINDOW=<opaque local id>
THINKBREAK_RECIPE_ID=<recipe id>
THINKBREAK_RECIPE_DIR=<absolute path>
THINKBREAK_WAIT_URL=<optional configured url>
```

脚本不得依赖 Prompt 环境变量。

### 6.4 返回责任

Recipe 的 `on-return` 只负责用户自定义清理，例如：

- 暂停用户自己启动的音乐；
- 关闭用户自己打开的页面；
- 执行用户指定的快捷指令。

Dispatcher 在 Recipe 返回、失败或超时后，仍必须执行通用来源窗口恢复。Recipe 不能阻止 Agent 返回。

## 7. 默认样板

### 7.1 ThinkBreak 娱乐页

官方可以提供一个关闭状态的样板：

```text
on-wait:
    打开维护者确认过的 ThinkBreak 娱乐页面

on-return:
    不要求网页做任何事情
    Dispatcher 恢复 Agent 窗口

on-attention:
    不要求网页做任何事情
    Dispatcher 立即恢复 Agent 窗口
```

网站页面可以展示娱乐内容，并提供一个明确说明的兴趣收集区域：

```text
如果未来可以看广告换模型调用额度，你愿意吗？
[愿意了解] [留下建议]
```

页面必须说明当前没有真实广告、没有 Token 奖励，也不代表未来一定提供奖励。

ThinkBreak 不向该页面传递 Prompt、回复、项目路径、窗口标题或 Agent Session 内容。

### 7.2 抖音样板

抖音只是另一个 Recipe：

```text
on-wait:
    打开 https://www.douyin.com/

on-return:
    用户自定义的尽力而为媒体清理
    Dispatcher 恢复 Agent 窗口
```

默认不承诺精确复用标签页、精确暂停单个视频或管理 Chrome Profile。用户可以让 Agent 根据自己的浏览器环境增强该 Recipe。

### 7.3 自定义 Recipe

用户可以说：

```text
等待时打开 B 站
等待时打开我的小说
等待时运行这个快捷指令
等待时打开我的网站
结束后不暂停任何媒体
结束后执行 cleanup.sh
```

ThinkBreak Skill 负责创建或修改 Recipe，并在执行前展示高影响动作。

## 8. ThinkBreak Skill

Skill 是项目主要用户界面。它负责：

1. 识别用户想配置的是延迟、总开关还是等待动作；
2. 检查当前宿主和操作系统；
3. 读取当前 Recipe；
4. 创建或修改脚本和 manifest；
5. 校验 URL、路径、脚本语法和超时；
6. 检查动作是否会读取凭证、上传数据或删除文件；
7. 修改前展示将执行的动作；
8. 提供测试、回滚和诊断命令。

示例：

```text
用户：等待时打开 B 站，任务结束后直接回来，不要暂停 B 站。

Skill：
- 创建 browser-bilibili Recipe
- on-wait 打开 B 站
- on-return 保持为空
- 保留 Dispatcher 的窗口恢复
- 询问是否立即测试
```

Skill 不强行把用户请求转换成预定义的 `media`、`reading` 或网站类型。它只需要遵守 Recipe 合约。

## 9. 配置与命令

用户配置目录：

```text
macOS:  ~/.config/thinkbreak/
Windows: %APPDATA%\\ThinkBreak\\
```

```text
config.json
sessions/
recipes/
logs/
```

最小配置：

```json
{
  "schema_version": 1,
  "enabled": true,
  "active_recipe": "tx0zero-entertainment",
  "delay_seconds": 2,
  "safety_timeout_seconds": 1800
}
```

最小命令：

```text
thinkbreak status
thinkbreak enable
thinkbreak disable
thinkbreak recipe list
thinkbreak recipe select <id>
thinkbreak recipe validate <id>
thinkbreak recipe reset
thinkbreak diagnose
```

这些命令供 Skill 和用户使用。它们不启动常驻服务。

## 10. Session 与并发规则

每次 `start` 创建一个 Session：

```text
session_id
host
source_window
started_at
switch_deadline
safety_deadline
state: pending | active | finished
```

规则：

1. `start` 捕获来源窗口并创建 pending Session；
2. 延迟期间收到 `stop`，只标记 Session 结束；
3. Worker 发现 Session 已结束时不执行 `on-wait`；
4. 多个 Session 同时存在时，最新成功执行 `on-wait` 的 Session 为前台拥有者；
5. 旧 Session 的 `stop` 只能清理自己的记录，不能恢复窗口或打断新 Session；
6. 当前拥有者收到 `stop` 或 `attention` 时执行清理并恢复来源窗口；
7. 达到安全时限时执行 `on-timeout`，然后强制恢复窗口；
8. Recipe 失败、超时或文件缺失时，Dispatcher 仍然恢复窗口。

## 11. 广告换额度的未来接口

当前版本不连接广告、账户或 Token 服务。

官方娱乐页只作为一个普通 `open_url` Recipe，页面可以收集用户是否愿意使用未来的激励服务。

未来如果用户量足够，维护者可以独立建设 Relay：

```text
ThinkBreak OSS Recipe
        ↓
用户主动打开 Relay 页面
        ↓
激励广告完成验证
        ↓
Relay Credits
        ↓
通过维护者自己的模型网关使用额度
```

该服务不属于 ThinkBreak Core，不修改本地 Hook 合约，也不应宣称向任何模型厂商账户直接充值官方 Token。

## 12. 隐私与安全

- Hook 事件不包含 Prompt 或 Agent 回复；
- 默认 Recipe 不联网，除非用户自己配置 URL 或命令；
- 官方娱乐 Recipe 的网址明文存储、可替换、可关闭；
- 不读取 Cookie、密码、Token 或浏览历史；
- 用户 Recipe 不自动从远程下载执行；
- 高影响命令由 Skill 在修改前展示；
- 每个 Recipe 动作有短超时；
- `on-return` 失败不阻塞窗口恢复；
- 日志只记录事件类型、Session ID 和错误码；
- 卸载默认保留用户 Recipe，显式清理时才删除配置。

## 13. 从 v0.1.0 App 原型迁移

旧实现的迁移策略：

1. 保留旧配置备份；
2. `ContentProfile` 转为 Recipe：
   - `kind == media` 生成打开 URL 的样板；
   - `kind == reading` 生成普通页面样板；
3. 保留名称、URL、启用状态和排序；
4. 保留总开关、延迟和安全超时；
5. 不再把 `kind` 当作 Core 行为分支；
6. 旧的 Chrome Apple Events、Swift App 和 Unix Socket 运行状态不迁移；
7. 迁移失败时保留旧文件并输出可操作错误。

最终删除：

- `Package.swift`；
- `Sources/ThinkBreakApp/`；
- Swift Core 和 Swift Hook；
- 菜单、设置窗口和 Chrome AppleScript 控制器；
- macOS-only 构建脚本；
- `.app` 发布包。

## 14. 测试计划

### Hook 生命周期

- 两秒内完成不执行 `on-wait`；
- 长任务执行当前 Recipe；
- Stop 取消 pending Worker；
- PermissionRequest 立即执行 attention 流程；
- 旧 Session 不抢当前 Session 焦点；
- 安全超时执行清理；
- Recipe 失败仍恢复来源窗口；
- Hook 缺失 Dispatcher 时正常退出并提示。

### Recipe

- 官方娱乐页 URL 可替换；
- B 站、小说和用户网站可以只通过新增 Recipe 使用；
- `on-return` 为空时仍恢复 Agent；
- macOS 和 Windows 使用各自脚本；
- 脚本超时不会阻塞 Agent；
- Recipe 不读取 Prompt 或凭证。

### 宿主

- Codex 和 Claude Code 使用各自 Hook Adapter；
- Hook stdout 不污染 Agent 上下文；
- 插件重复安装不会产生重复触发；
- Skill 可以完成启用、停用、选择和修改 Recipe；
- 安装器不依赖当前开发者路径。

## 15. 成功标准

- 用户不需要安装或管理独立应用；
- 用户不需要安装浏览器扩展；
- ThinkBreak 可以通过 Agent Skill 配置任意用户定义的等待动作；
- 默认抖音和官方娱乐页都只是可替换样板；
- Hook 可靠处理延迟、取消、授权返回、多任务和安全超时；
- Recipe 失败不会阻止返回 Agent；
- 项目不上传任务内容，不读取凭证，不默认连接广告或 Token 服务；
- 未来可以通过普通 Recipe 接入维护者网站，不修改 Core；
- 项目可以用一句话解释：Agent 工作时执行你的 Hook，结束时执行你的返回动作。
