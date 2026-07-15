# ThinkBreak 跨平台轻量插件架构设计

日期：2026-07-15

状态：跨平台重构方向，待用户确认后编写实现计划
目标平台：macOS 14+、Windows 10 1809+、Codex App、Claude Code、Google Chrome

## 1. 背景

ThinkBreak v0.1.0 已经用 Swift 实现 macOS 菜单栏应用、Codex / Claude Code 生命周期 Hook、两秒延迟、Chrome 等待窗口、媒体暂停、来源窗口恢复、多任务前台所有权和安全超时。

现有实现验证了产品行为，但把核心、macOS 自动化、SwiftUI 设置界面和 Chrome Apple Events 绑在一起，无法自然扩展到 Windows。继续沿用这套结构会形成两套产品：macOS 使用 Swift，Windows 再维护另一套 Runtime 和设置界面。

本次重构不做“双端各写一套 App”，而是把真正需要常驻的生命周期能力收敛为一个跨平台 Runtime。ThinkBreak 仍原生依附 Codex 和 Claude Code 的 Plugin Hooks，不引入 MCP Server，不在任务运行期间调用模型。

## 2. 产品定义

ThinkBreak 是 Codex 和 Claude Code 的跨平台等待切换插件：

1. 用户提交 Agent 任务后，ThinkBreak 等待设定延迟；
2. 任务仍在运行时，进入用户选定的等待体验；
3. 任务完成、请求授权或达到安全时限时，清理等待体验并恢复原 Agent 窗口；
4. 用户可以通过本地设置页、薄 CLI 或 ThinkBreak Skill 修改体验；
5. 抖音是默认样板，其他网页不是硬编码站点，而是同一通用网页体验的配置；
6. 网页体验运行在用户已有的普通 Chrome Profile 中，自然复用现有登录状态。

ThinkBreak 不负责实时判断用户应该看什么，也不在每次任务开始后再调用 Agent 编排等待内容。

## 3. 核心判断：需要 Runtime，不需要传统桌面 App

### 3.1 Hooks 能做什么

Hooks 适合发送短生命周期事件：

- `start`：任务开始；
- `stop`：任务完成；
- `attention`：任务等待用户授权或处理。

Hook 必须快速退出，不能在 Hook 内睡眠两秒、常驻轮询、操作浏览器或等待媒体脚本完成。

### 3.2 为什么不能只使用 Hook 脚本

以下状态跨越多个 Hook 调用，必须由一个独立 Runtime 持有：

- 两秒内收到 `stop` 时取消尚未发生的切出；
- 多任务同时运行时判断哪个 Session 拥有前台；
- 保存每个 Session 的准确来源窗口，而不是只记应用名；
- 旧任务结束时不抢走新任务的等待窗口；
- 宿主异常退出后执行安全超时；
- 在 Hook 进程已经退出后继续与 Chrome 通信；
- 在设置变化时立即取消等待或切换行为；
- 统一处理 macOS 与 Windows 的窗口恢复失败和降级提示。

这些能力如果用临时脚本、PID 文件和多个后台 `sleep` 进程拼接，也会形成一个更难管理的隐式 Runtime。

### 3.3 删除什么，保留什么

删除：

- Swift 业务代码；
- SwiftUI 设置窗口；
- macOS 专属 Core；
- 两套分别实现的桌面产品；
- Chrome Apple Events 作为核心浏览器控制方式。

保留并重写：

- 一个 Rust 跨平台可执行文件 `thinkbreak`；
- 同一可执行文件的 CLI 和后台 Runtime 模式；
- 一个很小的系统托盘入口；
- 一个由 Runtime 临时提供的本地设置网页；
- macOS / Windows 薄窗口适配层；
- Codex / Claude Code Provider-specific Hooks；
- 共用 Skill 和配置模型。

macOS 上仍可以把可执行文件装进 `ThinkBreak.app`，但 `.app` 只作为权限身份、自动启动和分发容器，不再承载 SwiftUI 桌面应用。Windows 使用同一 Rust Core 打包为普通 `.exe` 和托盘程序。

## 4. 设计原则

### 4.1 生命周期确定性优先

Hook、Runtime 和窗口恢复必须独立于 Agent、网页和媒体脚本。浏览器控制失败不能阻止返回来源窗口。

### 4.2 配置期使用 Agent，运行期不使用 Agent

用户可以说“把等待内容改成 B 站”或“新增一个小说体验”，由 ThinkBreak Skill 调用本地 CLI 写入经过校验的配置。任务运行期间只执行保存后的确定性配置。

### 4.3 跨平台核心只有一份

Session 状态机、配置、迁移、诊断、Hook 事件协议、浏览器消息协议和 CLI 全部使用 Rust 共享实现。平台目录只实现焦点捕获、窗口恢复、自动启动和系统提示。

### 4.4 不用桌面 Web 框架换掉 Swift

本次不使用 Electron、Tauri 或两套原生 UI。设置页使用 Runtime 在 `127.0.0.1` 临时提供的本地网页；关闭设置页后不保留通用 Web 服务。

### 4.5 不管理用户凭证

ThinkBreak 不读取、复制、导出或保存 Cookie、密码、登录 Token 和 Chrome 密码库。Chrome 配套扩展只在用户当前普通 Profile 中定位标签页和控制页面媒体，因此沿用 Chrome 已有登录状态。

### 4.6 本地优先

配置、窗口标识、Session 标识、浏览器绑定和诊断状态仅保存在本机。项目不增加遥测、分析 SDK、广告网络、账户系统或远程后端。

## 5. 范围

### 5.1 本次包含

- macOS 14+ 与 Windows 10 1809+；
- Codex 和 Claude Code Provider-specific Plugin Hooks；
- 共用 ThinkBreak Skill；
- Rust `thinkbreak` CLI + Runtime；
- 系统托盘总开关、当前体验、设置和诊断入口；
- 本地 Web 设置页；
- `browser-media` 和 `browser-page` 两种跨平台体验；
- 默认抖音体验；
- Chrome 配套扩展；
- 复用用户当前普通 Chrome Profile 和登录状态；
- 从 v0.1.0 配置迁移；
- Hook 信任、浏览器扩展、平台权限和安装诊断；
- “看广告换 Token”禁用玩梗开关。

### 5.2 暂不包含

- MCP Server 或 MCP 工具；
- 每个任务实时调用 Agent 选择等待内容；
- 后台编排 Agent；
- Electron、Tauri 或完整桌面设置应用；
- 第三方 Driver SDK、Driver 市场或在线模板市场；
- 设置页中的任意 Shell 命令；
- macOS Shortcuts、Power Automate 或跨平台任意命令体验；
- 抖音自动上刷、自动翻页、点赞、评论、关注或自动登录；
- Cookie、密码或 Token 读取；
- 真实广告、Token 奖励、账户、追踪或遥测；
- Firefox、Safari、Edge 的完整自动化保证；
- Linux 正式支持。

Linux 不进入首轮发布，但共享协议、配置和 Rust Core 不写死 macOS / Windows。未来增加 Linux 时只新增平台窗口适配和安装方式。

## 6. 总体架构

```text
Codex App                         Claude Code
    │                                 │
Codex Plugin Hooks               Claude Plugin Hooks
    │                                 │
    └────────── thinkbreak event ─────┘
                       │
                 Local IPC
       macOS: Unix Socket / Windows: Named Pipe
                       │
            thinkbreak Runtime（Rust）
             │          │           │
       Session Core  Config Core  Diagnostics
             │          │           │
      Platform Focus   Tray      Local Settings UI
             │
      macOS Adapter / Windows Adapter

Browser Experience:
Runtime ←─ local authenticated channel ─→ Chrome Companion Extension
                                                │
                                  existing profile / window / tab
```

配置链路：

```text
用户 → Codex / Claude Code → ThinkBreak Skill → thinkbreak CLI → 本地配置
用户 → 托盘 → 本地设置页 → Runtime → 本地配置
```

## 7. 仓库结构

```text
ThinkBreak/
├── Cargo.toml
├── crates/
│   ├── thinkbreak-core/          # 配置、Session、协议、迁移
│   ├── thinkbreak-cli/           # CLI 与 Runtime 入口
│   ├── thinkbreak-platform/      # 平台 trait
│   ├── thinkbreak-macos/         # macOS 窗口与权限适配
│   ├── thinkbreak-windows/       # Win32 窗口与提示适配
│   ├── thinkbreak-tray/          # 跨平台托盘
│   └── thinkbreak-settings/      # 内嵌静态设置页与本地服务
├── browser-extension/
│   ├── manifest.json
│   ├── service-worker.*
│   ├── content-script.*
│   └── options.*
├── plugin-src/
│   ├── shared/
│   │   ├── skills/thinkbreak/SKILL.md
│   │   └── dispatch-common.*
│   ├── codex/hooks/hooks.json
│   └── claude/hooks/hooks.json
├── installers/
│   ├── macos/
│   └── windows/
└── docs/
```

不要求最终代码严格按 crate 数量拆分，但边界必须保持一致，避免平台 API 渗入 Session Core。

## 8. Plugin、CLI 与 Runtime 边界

### 8.1 Plugin 是宿主安装边界

Codex 与 Claude Code 使用各自 Hook 清单和输出适配。两者共享事件规范和 Skill，但不能盲目共用同一份 `hooks.json`。

统一事件：

```json
{
  "schema_version": 1,
  "event": "start | stop | attention",
  "host": "codex | claude-code",
  "session_id": "provider session id",
  "prompt_id": "optional provider prompt id",
  "timestamp": "ISO-8601"
}
```

事件不得包含 Prompt、回复、文件内容或任务描述。

### 8.2 CLI 是短进程入口

`thinkbreak event ...` 只负责解析、校验并发送事件。Runtime 未运行时，CLI 尝试启动同一可执行文件的后台模式，然后在短预算内重试。启动失败时 Hook 仍以成功状态退出，不能阻塞 Codex 或 Claude Code。

### 8.3 Runtime 是可靠性边界

Runtime 持有：

- Session 状态机；
- 两秒延迟任务；
- 安全超时；
- 当前前台所有权；
- 来源窗口记录；
- 浏览器扩展连接；
- 托盘状态；
- 配置热加载和诊断状态。

Runtime 不读取 Prompt 文本，也不知道 Agent 正在执行什么任务。

### 8.4 Runtime 生命周期

- 用户登录后可自动启动；
- 未自动启动时由第一次 Hook 事件按需启动；
- 单实例运行；
- 托盘退出会停止自动切换，并在退出前尽力暂停等待媒体和恢复来源窗口；
- 崩溃重启后读取最小恢复记录，避免窗口长期留在等待体验中。

## 9. 为什么需要 Chrome 配套扩展

### 9.1 跨平台精确控制

macOS 的 Chrome Apple Events 无法移植到 Windows。Windows 系统媒体会话通常只能识别 Chrome 媒体会话，不能可靠区分 ThinkBreak 标签页与用户正在播放的其他标签页。

Chrome 配套扩展负责：

- 在当前 Chrome Profile 中查找或创建 ThinkBreak 等待标签页；
- 记录每个 Experience 对应的标签页；
- 聚焦正确的 Chrome 窗口和标签页；
- 在 `browser-media` 进入时恢复目标标签页的可见媒体；
- 离开时只暂停目标标签页内的音视频；
- 保留 `browser-page` 的标签、滚动和登录状态；
- 把绑定失效、权限缺失和脚本失败报告给 Runtime。

### 9.2 不读取登录凭证

扩展不申请 Cookies、密码、历史记录或下载权限。它只申请：

- 标签页和窗口定位所需权限；
- 用户为 Experience 配置的网站权限；
- 与本机 Runtime 通信所需权限。

新增站点时由用户确认相应网站访问权限。默认抖音只申请抖音域名，不申请所有网站权限。

### 9.3 降级模式

未安装或停用扩展时：

- `browser-page` 可以降级为系统默认方式打开 URL，并在任务结束时恢复来源窗口；
- `browser-media` 可以打开页面，但不承诺精确续播和暂停；
- Runtime 显示“安装 Chrome 配套扩展以启用媒体控制”；
- Hook 始终正常退出。

ThinkBreak 不通过 Chrome Remote Debugging 接管用户默认 Profile，也不要求用户启用远程调试端口。

## 10. 平台适配

### 10.1 macOS

macOS Adapter 负责：

- 获取当前前台应用、进程和窗口标识；
- 使用 Accessibility API 恢复准确来源窗口和输入焦点；
- 在权限缺失时提供系统设置入口；
- 注册登录启动；
- 提供 Unix Domain Socket；
- 托盘菜单和本地通知。

Rust 可执行文件装入 `.app` Bundle，以获得稳定的权限身份和分发路径。Bundle 不包含 Swift 业务代码。

### 10.2 Windows

Windows Adapter 负责：

- 获取当前前台 `HWND`、进程 ID 和宿主信息；
- 使用 Win32 / UI Automation 尝试恢复来源窗口；
- 提供当前用户私有 Named Pipe；
- 注册登录启动；
- 托盘菜单、Toast 或任务栏提示。

Windows 对程序强制抢占前台有限制。自动恢复失败时必须：

1. 闪烁对应任务栏窗口；
2. 显示本地通知；
3. 不反复抢焦点或模拟无界限输入。

产品文档必须明确：Windows 会尽力自动返回，但操作系统可能要求用户点击已高亮的 Codex 或终端窗口。

### 10.3 平台能力表

| 能力 | macOS | Windows |
| --- | --- | --- |
| 两秒延迟与取消 | 完整 | 完整 |
| 多 Session 所有权 | 完整 | 完整 |
| Chrome 标签复用 | 扩展 | 扩展 |
| 媒体精确暂停/续播 | 扩展 | 扩展 |
| 普通网页位置保留 | 扩展 | 扩展 |
| 来源窗口恢复 | Accessibility | Win32 / UI Automation，受前台限制 |
| 本地 IPC | Unix Socket | Named Pipe |
| 设置页 | 本地 Web UI | 本地 Web UI |
| 系统入口 | 托盘 / app bundle | 托盘 / exe |

## 11. 生命周期状态机

每个 Session 保存：

```text
host
sessionID
promptID              可选
sourceWindow          平台不透明标识
startedAt
switchDeadline
safetyDeadline
state                 pending | browsing | attention | finished
```

全局保存：

```text
foregroundOwnerSessionID
activeExperienceID
browserConnectionState
```

规则：

1. `start(session)`：捕获来源窗口，进入 `pending`，启动延迟；
2. 延迟内收到同 Session 的 `stop`：取消，不切换；
3. 延迟到期且仍运行：进入当前 Experience，并把该 Session 设为前台所有者；
4. `stop(session)`：仅当前所有者可以触发普通返回，旧 Session 只清理自身状态；
5. `attention(session)`：立即清理当前等待体验并恢复该 Session 对应来源窗口；
6. `timeout(session)`：清理体验、恢复来源并提示；
7. 关闭总开关：取消所有 pending，清理当前体验并返回；
8. Runtime 退出：在短预算内执行同样的清理和返回。

退出顺序：

```text
收到 stop / attention / timeout / disable
    ↓
请求 Chrome 扩展暂停目标媒体（best effort，有短超时）
    ↓
到达超时或完成
    ↓
无条件尝试恢复来源窗口
    ↓
失败时执行平台降级提示
    ↓
释放 Session 状态
```

## 12. 配置模型

### 12.1 全局设置

```text
schemaVersion
isEnabled
activeExperienceID
switchDelaySeconds        默认 2 秒
safetyTimeoutSeconds      默认 30 分钟
experiences
browserBinding
```

### 12.2 Experience

```text
id
name
enabled
kind
configuration
```

第一阶段只支持：

- `browser-media`
- `browser-page`

配置使用 Rust 带类型枚举和版本化 Schema，不使用任意无校验字典。

### 12.3 browser-media

```text
url
reuseTab                  默认 true
resumeVisibleMedia        默认 true
pauseAllMediaOnLeave      默认 true
```

适用于抖音、B 站、YouTube 和网页音乐。进入时只操作该 Experience 绑定标签页内当前可见的媒体；离开时暂停该标签页内音视频。网页阻止自动播放时不绕过浏览器策略。

### 12.4 browser-page

```text
url
reuseTab                  默认 true
preservePageState         固定 true
```

适用于小说、漫画、文档和普通网页。进入时打开或复用标签页，离开时不刷新、不修改滚动位置。

### 12.5 默认抖音体验

```text
id: builtin-douyin
name: 抖音
kind: browser-media
url: https://www.douyin.com/
reuseTab: true
resumeVisibleMedia: true
pauseAllMediaOnLeave: true
enabled: true
```

抖音只是内置样板，不在 Core 中存在站点专属分支。用户可以删除、禁用、复制或替换它。

## 13. Chrome Profile、登录与标签绑定

### 13.1 登录复用

扩展安装在用户正常使用的 Chrome Profile 中，因此标签页直接使用该 Profile 已有的抖音、B 站或其他网站登录状态。ThinkBreak 不创建无痕窗口，不创建独立 User Data Directory，不读取 Cookies 数据库。

### 13.2 多 Profile

每个 Chrome Profile 分别安装和运行扩展。用户在目标 Profile 的扩展界面选择“将当前窗口绑定为 ThinkBreak 等待窗口”。Runtime 保存扩展实例生成的不透明绑定 ID，不读取 Chrome Profile 名称或凭证。

如果多个 Profile 的扩展实例同时连接且没有明确绑定，ThinkBreak 不静默选择，设置页要求用户完成绑定。

### 13.3 标签复用

扩展为每个 Experience 记录标签 ID、窗口 ID 和 URL 匹配信息：

1. 标签存在时直接复用；
2. 标签被关闭时在绑定窗口重建；
3. Chrome 重启后按 URL 和 Experience 标记恢复；
4. 多个候选无法唯一判断时要求用户重新绑定；
5. 登录过期时由用户在正常页面重新登录。

## 14. ThinkBreak Skill

Codex 和 Claude Code 共用一份 ThinkBreak Skill，把自然语言配置请求转换为经过验证的 CLI 调用。

示例：

| 用户表达 | Skill 行为 |
| --- | --- |
| “把等待内容改成 B 站” | 新增或更新 `browser-media`，设为当前体验 |
| “新增一个小说体验” | 询问 URL，新增 `browser-page` |
| “任务超过 5 秒再跳出去” | 修改延迟为 5 秒 |
| “先关闭 ThinkBreak” | 关闭总开关 |
| “恢复默认抖音” | 恢复或启用内置样板 |
| “检查为什么没有暂停” | 运行诊断，检查扩展连接和网站权限 |

Skill 约束：

- 优先调用 CLI，不直接编辑配置文件；
- URL 缺失或不确定时直接询问用户；
- 不生成任意 Shell 配置；
- 不读取浏览历史、Cookie 或 Prompt 内容；
- 修改后运行校验；
- 只有用户明确要求时才执行实际跳出 / 跳回测试。

## 15. CLI 接口

```text
thinkbreak status [--json]
thinkbreak enable
thinkbreak disable
thinkbreak settings
thinkbreak diagnose [--json]
thinkbreak event <start|stop|attention> ...

thinkbreak experience list [--json]
thinkbreak experience add-browser \
  --name <name> \
  --url <url> \
  --mode <media|page>
thinkbreak experience update <id> ...
thinkbreak experience remove <id>
thinkbreak experience select <id>
thinkbreak experience move <id> --before <id>
thinkbreak experience restore-defaults

thinkbreak browser status [--json]
thinkbreak browser bind-current
thinkbreak browser open-extension
thinkbreak config validate
```

规则：

- 正常输出面向人类；
- `--json` 为 Skill 提供稳定机器格式；
- 修改命令原子写入并带配置版本；
- URL 只允许 `https` 和用户明确启用的 `http://localhost`；
- Hook 调用不向 stdout 输出会污染 Agent 上下文的内容；
- Runtime 不在线时配置命令可以直接使用共享 Config Core，事件命令负责按需启动 Runtime。

## 16. 托盘与本地设置页

### 16.1 托盘

托盘只承担高频控制：

```text
ThinkBreak：开启 / 关闭
当前体验：抖音 ›
状态：已连接 / 缺少扩展 / 缺少权限 / 正在等待
打开设置…
绑定当前 Chrome 窗口
诊断…
退出
```

不在托盘中实现复杂编辑器。

### 16.2 本地设置页

`thinkbreak settings` 启动一次性本地设置会话并在默认浏览器打开随机端口和随机会话 Token。只监听 `127.0.0.1`，不监听局域网地址。页面关闭或空闲超时后停止设置服务。

设置页包含：

- 总开关；
- 当前体验；
- 新增、编辑、删除、排序体验；
- 类型：视频/音频网页、普通网页；
- 延迟和安全超时；
- Chrome 扩展状态、等待窗口绑定和站点权限；
- Codex / Claude Code Hook 安装与信任状态；
- macOS / Windows 窗口权限和恢复能力；
- 本地诊断信息；
- “看广告换 Token”玩梗区。

设置页不加载远程脚本、字体、统计或广告资源。

### 16.3 “看广告换 Token”

该区域显示一个固定关闭且不可操作的开关，并说明：

> 概念功能：如果未来大模型真的支持看广告换 Token，这里也许会亮起来。当前不会播放广告，也不会增加 Token。

它不写入功能配置，不产生网络请求，不连接 OpenAI、Anthropic 或任何广告服务。

## 17. 本地通信与安全

### 17.1 Hook IPC

- macOS 使用当前用户私有 Unix Domain Socket；
- Windows 使用限制为当前用户 SID 的 Named Pipe；
- 每条消息有长度上限和 Schema 校验；
- 不接受远程连接；
- 非法事件记录最小诊断后丢弃。

### 17.2 浏览器通信

Runtime 与 Chrome 扩展使用 Chrome Native Messaging：

1. 扩展 Service Worker 调用 `chrome.runtime.connectNative("com.tx0zero.thinkbreak")`；
2. Chrome 启动同一 `thinkbreak` 可执行文件的 `native-host` 模式；
3. `native-host` 使用 Chrome 的长度前缀 JSON 协议连接扩展，并通过 Runtime 的私有 IPC 转发消息；
4. 扩展保持一个长连接；连接断开时按退避策略重连；
5. 安装器在 macOS 和 Windows 注册 Native Messaging Host 清单，并只允许 ThinkBreak 的固定扩展 ID；
6. 开发构建使用仓库内固定公钥生成稳定扩展 ID，发布构建使用同一 ID；
7. 发布版优先从 Chrome Web Store 安装，源码开发版允许用户手动加载 unpacked 扩展。

通信只包含：

- Experience ID；
- URL 和预期行为；
- 标签 / 窗口的不透明标识；
- `enter`、`leave`、`bind`、`status`；
- 错误码和能力状态。

不得传输 Cookie、页面正文、浏览历史、Prompt 或 Agent 回复。

### 17.3 设置服务

- 只监听 loopback；
- 每次打开使用新的高熵 Token；
- 校验 Origin；
- 有短空闲超时；
- 所有修改经过 Config Core 校验；
- 页面关闭后自动停止，不作为远程控制 API。

## 18. 配置迁移与仓库重构

### 18.1 配置迁移

从 v0.1.0 迁移：

- `ContentProfile.kind == media` → `browser-media`；
- `ContentProfile.kind == reading` → `browser-page`；
- 保留 `id`、`name`、`url`、`enabled` 和排序；
- `activeProfileID` → `activeExperienceID`；
- 保留总开关、切出延迟和安全超时；
- 现有抖音配置不重复创建；
- 迁移前保留备份；
- 迁移失败时不覆盖旧文件。

`macos-shortcut` 尚未进入已发布配置，因此不作为跨平台 Schema 的正式类型。若本地开发配置中存在该类型，迁移工具保留原始备份并提示暂不支持，不静默转换为命令执行。

### 18.2 代码迁移

重构不是在 Swift 项目旁边新增 Windows 项目。迁移顺序：

1. 用 Rust Core 的测试复刻现有 SessionCoordinator 行为；
2. 实现兼容旧格式的配置读取和迁移；
3. 实现 CLI、Runtime 和 IPC；
4. 实现 Chrome 扩展与降级网页打开；
5. 实现 macOS Adapter，替换当前 Swift Runtime；
6. 实现 Windows Adapter；
7. 两个平台通过核心验收后删除 Swift Package、Swift Sources 和旧构建脚本；
8. 更新安装器、CI、README、截图和发布包。

在新 Runtime 通过行为测试前保留旧 Swift 代码作为对照，但不继续向旧实现添加新功能。最终仓库不保留双实现。

### 18.3 插件安装迁移

安装器检测并清理重复存在的 `thinkbreak@plugins-cli` 与本地 Marketplace 安装，只保留一个明确来源。Codex 还要检查 Hook 是否已信任，不能把“插件已启用”当作“Hook 已生效”。

## 19. 故障处理

### 19.1 Runtime 未运行

Hook CLI 在短预算内启动 Runtime 并重试。失败后退出成功，Agent 正常继续，诊断页显示最近错误。

### 19.2 Chrome 扩展未安装或断开

网页打开能力降级；媒体控制不可用；不阻止切回。

### 19.3 网站权限缺失

扩展只提示用户为当前 Experience 域名授权，不扩大到所有网站。任务结束仍返回来源窗口。

### 19.4 Chrome 未运行

Runtime 正常打开配置 URL。Chrome 启动并加载扩展后完成绑定；若无法确定目标 Profile，提示用户绑定，不静默选错账号。

### 19.5 标签被关闭

扩展在已绑定窗口重建标签。绑定窗口失效时要求重新绑定。

### 19.6 来源窗口失效

尝试恢复同进程的最近窗口；仍失败则通知用户，不激活无关应用。

### 19.7 Windows 拒绝前台切换

闪烁准确任务栏窗口并发送通知，不循环调用前台 API，不模拟任意键盘输入。

### 19.8 配置并发修改

配置仓库使用原子写入、版本号和冲突检测。CLI 与设置页发生版本冲突时拒绝覆盖并要求刷新。

## 20. 测试计划

### 20.1 共享 Core

- 两秒内完成不切换；
- 长任务延迟后进入体验；
- Stop 返回；
- attention 立即返回；
- 旧任务 Stop 不抢焦点；
- 安全超时返回；
- 总开关取消 pending 和当前体验；
- Runtime 重启恢复；
- 配置迁移、原子写入和冲突检测；
- Hook 事件不含任务内容。

### 20.2 Chrome 扩展

- 默认抖音标签复用当前 Profile 登录；
- B 站等新增媒体体验无需 Core 改站点代码；
- 小说标签保留滚动位置；
- 每个 Experience 保留独立标签；
- 只暂停目标标签页媒体；
- 不申请 Cookies 或历史权限；
- 站点权限按域名请求；
- 多 Profile 歧义要求绑定；
- 扩展缺失时正确降级。

### 20.3 macOS

- Codex App 准确恢复；
- Terminal / iTerm 中 Claude Code 恢复原窗口；
- Accessibility 未授权时给出入口且不阻塞 Hook；
- `.app` Bundle 重启后权限身份稳定；
- Unix Socket 仅当前用户可访问。

### 20.4 Windows

- Codex App 恢复原 `HWND`；
- Windows Terminal / PowerShell 中 Claude Code 恢复原窗口；
- 前台切换被拒绝时任务栏闪烁和通知生效；
- Named Pipe 仅当前用户可访问；
- Chrome Profile 和标签复用；
- 登录启动、重复安装和卸载不破坏用户数据。

### 20.5 Plugin 与 Skill

- Codex / Claude Code 使用各自 Hook Adapter；
- Hook stdout 不污染 Agent 上下文；
- Hook 未信任、CLI 缺失、Runtime 崩溃时不阻塞宿主；
- Skill 可以新增 B 站、小说或任意 HTTPS 网页体验；
- Skill 不直接编辑 JSON；
- 诊断可以区分 Hook、Runtime、窗口权限、扩展和网站权限问题。

### 20.6 发布与隐私

- macOS 和 Windows 构建、测试、清单及安装器校验；
- 发布包无用户路径、Cookie、Token、浏览记录和个人配置；
- 本地设置页无远程资源；
- “看广告换 Token”无网络请求；
- 卸载默认保留配置并提供显式彻底清理选项。

## 21. 成功标准

- 仓库最终不再包含 Swift 业务实现；
- macOS 与 Windows 共用同一 Rust Session、配置、CLI 和协议 Core；
- 用户安装默认抖音体验后可复用当前 Chrome Profile 登录；
- 用户可以通过设置页或 Codex / Claude Code Skill 改成 B 站、小说或任意 HTTPS 网页，不修改 Hook；
- 运行期间没有模型调用、MCP Server、Electron、Tauri 或远程后端；
- 媒体只在目标等待标签页内暂停和续播；
- Stop、attention 和安全超时优先恢复来源窗口；
- Windows 无法自动抢回焦点时给出准确、克制的降级提示；
- 现有 v0.1.0 配置可以迁移；
- 项目仍能用一句话解释：Agent 工作时跳出去，结束时自动回来。
