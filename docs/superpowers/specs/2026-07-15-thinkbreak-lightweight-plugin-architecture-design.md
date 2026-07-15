# ThinkBreak 轻量原生插件架构设计

日期：2026-07-15

状态：已确认方向，待实现计划
目标项目：ThinkBreak（macOS 14+、Codex App、Claude Code、Google Chrome）

## 1. 背景

ThinkBreak v0.1.0 已经实现 Codex / Claude Code 生命周期 Hook、两秒延迟、Chrome 等待窗口、媒体暂停、来源窗口恢复、多任务前台所有权和安全超时。

现有模型把等待内容固化为 `ContentProfile(name, url, kind: media | reading)`，并把抖音作为唯一默认 Profile。这个模型可以完成演示，但继续增加 B 站、小说、音乐或其他网页时，容易把核心演变成网站列表或通用自动化平台。

新版设计保留抖音的开箱即用体验，同时把产品核心收敛到可靠的“跳出 / 跳回”生命周期。用户可以直接在菜单中配置，也可以让 Codex 或 Claude Code 通过 ThinkBreak Skill 调用薄 CLI 完成配置。运行期间不调用模型，不引入 MCP Server。

## 2. 产品定义

ThinkBreak 是原生依附于 Codex 和 Claude Code 插件生态的 macOS 等待切换工具：

1. 用户提交 Agent 任务后，ThinkBreak 等待设定延迟；
2. 任务仍在运行时，进入用户当前选择的等待体验；
3. 任务完成、需要授权或达到安全时限时，清理等待体验并恢复原 Agent 窗口；
4. 用户可以通过菜单或 Agent Skill 修改等待体验；
5. 抖音是默认体验，并复用用户普通 Chrome Profile 中已有的登录状态。

ThinkBreak 不负责决定用户“应该看什么”，也不在每次任务中调用模型进行实时编排。

## 3. 设计原则

### 3.1 生命周期确定性优先

Hook 和 Runtime 必须独立完成跳出、跳回和失败恢复。Agent、网页脚本、媒体暂停或快捷指令失败，均不得阻止返回原窗口。

### 3.2 配置期使用 Agent，运行期不使用 Agent

用户可以对 Codex 或 Claude Code 说“把等待内容改成 B 站”，由 Skill 指导 Agent 调用本地 CLI 修改配置。任务真正运行时，只读取已经验证并保存的本地配置。

### 3.3 保持轻量

不引入 MCP Server、后台编排 Agent、浏览器扩展、Driver 商店、工作流编辑器或远程服务。Unix Socket 仅用于 Hook CLI 与菜单栏 Runtime 的内部通信。

### 3.4 不管理用户凭证

ThinkBreak 不读取、复制、导出或保存 Cookie、密码、登录 Token 和 Chrome 密码库。它只操作用户现有普通 Chrome 窗口和标签页，让 Chrome 自己使用该 Profile 的登录状态。

### 3.5 本地优先

配置、窗口绑定、Session 标识和诊断状态只保存在本机。不增加遥测、分析 SDK、广告网络或真实 Token 奖励。

## 4. 范围

### 4.1 本次包含

- Codex 和 Claude Code 的原生 Plugin Hooks；
- 共用 ThinkBreak Skill；
- 一个薄的本地 `thinkbreak` CLI；
- macOS 菜单栏 Runtime；
- `browser-media`、`browser-page` 和 `macos-shortcut` 三种通用体验行为；
- 默认抖音体验；
- 绑定并复用用户当前普通 Chrome 窗口；
- 从 v0.1.0 配置无损迁移；
- Hook 信任、权限和安装诊断；
- 现有“看广告换 Token”禁用玩梗开关。

### 4.2 本次不包含

- MCP Server 或 MCP 工具；
- 每个任务实时调用 Agent 选择等待内容；
- 第三方 Driver SDK、Driver 市场或在线模板市场；
- 设置界面中的任意 Shell 命令输入框；
- Chrome 扩展；
- 抖音自动上刷、自动翻页、点赞、评论、关注或自动登录；
- Cookie、密码或 Token 读取；
- 真实广告、Token 奖励、账户系统、跟踪或网络遥测；
- 除 Google Chrome 之外的浏览器自动化保证。

## 5. 总体架构

```text
Codex App                         Claude Code
    │                                 │
Codex Plugin Hooks               Claude Plugin Hooks
    │                                 │
    └────────── thinkbreak event ─────┘
                       │
             本地 Unix Socket（内部）
                       │
             ThinkBreak Menu Runtime
               │                 │
        Session Kernel     Experience Executor
               │                 │
        来源窗口恢复       Chrome / Shortcuts

配置链路：
用户 → Codex/Claude Code → ThinkBreak Skill → thinkbreak CLI → 本地配置
```

### 5.1 Plugin 是安装边界

仓库继续同时支持 Codex 和 Claude Code，但生成两个 Provider-specific 插件包：

```text
plugin-src/
├── shared/
│   ├── skills/thinkbreak/SKILL.md
│   └── dispatch-common.sh
├── codex/
│   └── hooks/hooks.json
└── claude/
    └── hooks/hooks.json
```

发布或安装时分别生成 Codex 与 Claude Code 插件目录。两者共享 Skill 和事件发送实现，但保留各自的 Hook 配置和中性输出格式，避免两个宿主在 Hook 输出语义、信任流程或支持事件上的差异互相影响。

### 5.2 Runtime 是可靠性边界

菜单栏 Runtime 持有 Session 状态机、窗口捕获、延迟任务、安全超时和当前前台 Session 所有权。Runtime 不读取 Prompt 文本，也不需要知道 Agent 正在执行什么任务。

### 5.3 CLI 是配置入口

`thinkbreak` CLI 是按需运行的本地程序，不常驻、不联网。它负责：

- 向 Runtime 发送生命周期事件；
- 查询运行状态和权限状态；
- 校验、增删、修改、选择和测试等待体验；
- 输出机器可读 JSON，供 Skill 稳定调用；
- 必要时后台启动 ThinkBreak.app。

CLI 与 App 共用相同的 Core 模型和配置仓库，避免 CLI 直接拼接或破坏配置文件。

## 6. 生命周期与事件适配

### 6.1 宿主事件

Codex 和 Claude Code 的 Hook Adapter 将宿主事件标准化为内部事件：

```json
{
  "schema_version": 1,
  "event": "start | stop | attention",
  "host": "codex | claude-code",
  "session_id": "...",
  "prompt_id": "可选",
  "timestamp": "ISO-8601"
}
```

只传递 Session 关联所需字段，不传递 Prompt、工具参数、对话记录或项目文件内容。

### 6.2 Hook 行为

- `UserPromptSubmit`：发送 `start`；Hook 本身不等待两秒，也不操作 Chrome；
- `Stop`：发送 `stop`；返回宿主要求的中性成功输出；
- `PermissionRequest`：发送 `attention`；返回宿主要求的中性输出，不自动批准或拒绝权限；
- Runtime 未运行时：CLI 使用 `open -gj -a ThinkBreak` 尝试后台启动，并在短时间内重试连接；
- 任何失败：Hook 记录简短本地诊断后以成功状态退出，不阻塞 Agent。

Codex 与 Claude Code 使用独立 Adapter，以适配各自的 stdin 字段、JSON stdout 和 Hook 信任流程。

### 6.3 Session Kernel

Session Kernel 保持“最新任务拥有前台控制权”：

1. `start(session)`：读取当前配置，捕获来源窗口，取消旧延迟和旧安全超时，将该 Session 设为当前所有者；
2. 延迟到期：若 Session 仍为当前所有者，执行当前 Experience 的进入动作；
3. `stop(session)`：仅当前所有者可以触发普通返回；旧 Session 只清理自己的来源记录；
4. `attention(session)`：立即清理等待体验并恢复该 Session 对应的来源窗口；
5. `timeout(session)`：清理体验、恢复来源并显示本地警告；
6. 手动停用总开关：取消所有待执行切换，若当前处于等待体验中则清理并返回。

### 6.4 返回顺序

退出流程必须设置短清理预算：

```text
收到 stop / attention / timeout
    ↓
请求 Experience 执行 leave（best effort）
    ↓
到达清理预算或 leave 完成
    ↓
无条件恢复来源窗口和输入焦点
    ↓
释放 Session 状态
```

媒体暂停或快捷指令失败只能产生警告，不能阻止恢复窗口。

## 7. 配置模型

### 7.1 全局设置

```text
schemaVersion
isEnabled
activeExperienceID
switchDelaySeconds        默认 2 秒
safetyTimeoutSeconds      默认 30 分钟
experiences
chromeBinding
```

### 7.2 Experience

```text
id
name
enabled
kind
configuration
```

`kind` 第一阶段仅支持：

- `browser-media`
- `browser-page`
- `macos-shortcut`

配置使用带类型的 Codable 枚举，而不是任意无校验字典。配置文件包含 `schemaVersion`，由 Core 统一迁移和校验。

### 7.3 browser-media

```text
url
reuseTab                  默认 true
resumeVisibleMedia        默认 true
pauseAllMediaOnLeave      默认 true
```

适用于抖音、B 站、YouTube、音乐网页等。进入时只尝试恢复当前可见媒体；离开时暂停该等待标签页内的音视频。网页阻止自动播放时不绕过浏览器策略，只激活页面并给出非阻塞提示。

### 7.4 browser-page

```text
url
reuseTab                  默认 true
preservePageState         固定 true
```

适用于小说、漫画、文档和普通网页。进入时打开或复用标签页；离开时不刷新、不修改滚动位置、不执行媒体控制脚本。

### 7.5 macos-shortcut

```text
enterShortcutName
leaveShortcutName         可选
cleanupTimeoutSeconds     有严格上限
```

ThinkBreak 只运行用户已经存在的 macOS 快捷指令，不在应用内创建或编辑快捷指令，也不接受任意 Shell 文本。进入快捷指令失败时保持原窗口；离开快捷指令失败时仍强制返回 Agent。

## 8. 默认抖音体验与 Chrome 登录状态

### 8.1 默认配置

全新安装默认创建：

```text
名称：抖音
类型：browser-media
网址：https://www.douyin.com/
复用标签页：开启
进入时恢复可见媒体：开启
离开时暂停媒体：开启
```

抖音是默认 Experience，但不是 Session Kernel 的特殊分支。用户删除所有体验后可以通过“恢复默认体验”重新创建。

### 8.2 凭证复用原则

ThinkBreak 使用用户普通 Chrome 窗口，不使用无痕模式，不创建独立 User Data Directory，不读取 Cookies 数据库。只要等待窗口属于用户已经登录抖音的 Chrome Profile，Chrome 会自行复用该 Profile 的登录状态。

### 8.3 轻量窗口绑定

不实现完整 Chrome Profile 管理器。菜单提供“使用当前 Chrome 窗口作为等待窗口”：

1. 用户切换到已经登录抖音的目标 Chrome Profile 和普通窗口；
2. 用户从 ThinkBreak 菜单执行绑定；
3. Runtime 记录 Chrome 窗口标识及标签页匹配信息；
4. 后续优先复用该窗口和已有抖音标签页。

绑定信息失效或尚未绑定时：

1. 若能唯一找到匹配 URL 的现有标签页，则自动绑定该标签页所在窗口；
2. 若没有匹配标签页但 Chrome 只有一个普通窗口，则使用该窗口并打开网址；
3. 若 Chrome 尚未运行，则正常启动 Chrome，在其默认普通 Profile 中创建等待窗口并打开网址；
4. 若存在多个候选窗口、多个匹配标签页或无法安全确定 Profile，则不静默选择，显示“请在目标 Chrome 窗口中重新绑定”的菜单提示；
5. 用户重新绑定前，Hook 仍正常退出且不阻塞 Agent。

这保证多 Profile 用户不会被静默切换到错误账号，同时避免读取 Chrome Profile 或凭证数据。

### 8.4 登录失效

ThinkBreak 不绕过抖音的登录、扫码、验证码或风控。登录失效时，用户在等待窗口中正常重新登录，之后继续复用同一标签页。

## 9. ThinkBreak Skill

Plugin 为 Codex 和 Claude Code 提供同一份 `thinkbreak` Skill。Skill 的职责是把自然语言配置请求转换为经过验证的 CLI 调用。

支持的典型请求：

- “把等待内容改成 B 站”；
- “新增一个看小说的方案，退出时不要修改页面”；
- “把切出延迟改成 5 秒”；
- “暂时关闭 ThinkBreak”；
- “测试当前等待体验”；
- “检查为什么任务没有切出去”；
- “恢复默认抖音方案”。

Skill 约束：

- 优先调用 CLI，不直接编辑配置 JSON；
- 修改或删除体验前先读取当前状态；
- 删除、覆盖和运行快捷指令等高影响操作要向用户说明；
- 不读取或传递浏览器凭证；
- 不把 Prompt 内容写入 ThinkBreak 配置；
- 不承诺网页能够绕过自动播放或登录限制；
- 配置完成后使用 CLI 校验，测试动作由用户明确要求或确认后执行。

用户仍可完全不用 Skill，只通过菜单栏应用操作。

## 10. CLI 接口

CLI 使用清晰的用户术语，避免要求用户理解内部 Driver 架构。

```text
thinkbreak status [--json]
thinkbreak doctor [--json]
thinkbreak enable
thinkbreak disable

thinkbreak preset list [--json]
thinkbreak preset add --name <name> --url <url> --behavior media|page
thinkbreak preset add-shortcut --name <name> --enter <shortcut> [--leave <shortcut>]
thinkbreak preset update <id|name> ...
thinkbreak preset select <id|name>
thinkbreak preset remove <id|name>
thinkbreak preset restore-default
thinkbreak preset test [<id|name>]

thinkbreak config set-delay <seconds>
thinkbreak config set-timeout <seconds>
thinkbreak chrome bind-current

thinkbreak event start --host <host>
thinkbreak event stop --host <host>
thinkbreak event attention --host <host>
```

要求：

- 所有修改命令由 Core 校验并原子写入；
- URL 只接受 `http` 和 `https`；
- 名称冲突、未知 Experience 和非法数值返回清晰错误；
- `--json` 输出保持稳定，供 Skill 使用；
- 生命周期 `event` 子命令属于内部接口，帮助中标记为 internal；
- Hook 路径的事件发送必须快速、有严格超时并始终不阻塞宿主。

为了减少二进制数量，现有 `thinkbreak-hook` 功能并入 `thinkbreak event`。升级时保留一个兼容入口或迁移旧 Hook 配置，确保 v0.1.0 用户不会出现失效 Hook。

## 11. 菜单栏与设置界面

### 11.1 菜单栏

保留轻量菜单：

```text
ThinkBreak：开启 / 关闭
当前体验：抖音 ▸
使用当前 Chrome 窗口作为等待窗口
测试当前体验
状态 / 需要处理的提示
设置…
退出
```

总开关必须直接可见。切换当前体验立即保存，但不改变正在执行的 Session；新选择从下一次任务生效。

### 11.2 设置窗口

设置窗口包含：

- 总开关；
- 当前体验；
- Experience 列表的新增、编辑、删除和排序；
- 类型选择：视频/音频网页、普通网页、macOS 快捷指令；
- 切出延迟和安全超时；
- Chrome 等待窗口绑定状态；
- 辅助功能、Chrome Apple Events 和 Hook 状态诊断；
- “看广告换 Token”禁用玩梗区域。

“看广告换 Token”区域保留固定关闭且不可操作的玩梗开关与说明，不写入配置、不展示广告素材、不访问网络、不改变 Token。

### 11.3 Agent 修改后的同步

App 监听本地配置变化或在激活时重新加载。CLI 修改成功后，菜单和设置窗口无需重启即可显示新配置。若设置窗口存在未保存编辑，必须提示冲突，不能静默覆盖。

## 12. 权限与安全

### 12.1 必需权限

- macOS 辅助功能：捕获和恢复窗口焦点；
- Chrome “Allow JavaScript from Apple Events”：仅 `browser-media` 的播放/暂停控制需要；
- Codex / Claude Code Plugin Hook 信任：由用户在宿主中明确确认。

`browser-page` 在不执行媒体控制时仍可能使用 Chrome Apple Events 打开和定位标签页，但不得读取页面内容。

### 12.2 本地 IPC

- Unix Socket 位于用户私有的 Application Support 或临时运行目录；
- Socket 和父目录仅当前用户可访问；
- 事件负载设定大小上限；
- 只接受已定义的事件和字段；
- 不接受可执行命令、脚本内容或任意文件路径；
- App 退出时清理 Socket 文件。

### 12.3 快捷指令边界

快捷指令由用户在 macOS 中创建和授权。ThinkBreak 只按名称运行。设置界面和 CLI 显示即将运行的快捷指令名称，且设置清理超时。快捷指令不能覆盖 Session Kernel 的强制返回逻辑。

## 13. 配置迁移

从 v0.1.0 迁移到新版时：

- `ContentProfile.kind == media` → `Experience.kind == browser-media`；
- `ContentProfile.kind == reading` → `Experience.kind == browser-page`；
- 保留 `id`、`name`、`url`、`enabled` 和排序；
- `activeProfileID` → `activeExperienceID`；
- 保留总开关、切出延迟和安全超时；
- 现有默认抖音配置不重复创建；
- 迁移前保留配置备份；
- 迁移失败时继续使用旧配置并显示可操作错误，不覆盖原文件。

插件安装迁移还要检测并处理当前可能同时存在的 `thinkbreak@plugins-cli` 与本地 Marketplace 重复安装。安装脚本只保留一个明确来源，并在 README 中提供检查和清理方式。

## 14. 故障处理

### 14.1 App 未运行

Hook CLI 尝试后台启动 App，并在短预算内连接。失败后记录诊断并退出成功，不影响 Agent。

### 14.2 权限缺失

不反复弹系统设置。菜单状态区显示缺失权限和打开设置入口。Hook 继续正常退出。

### 14.3 Chrome 未运行

进入网页体验时正常启动 Chrome。若尚未绑定等待窗口，则使用当前普通 Chrome 窗口；无法安全确定时提示绑定，不静默使用错误 Profile。

### 14.4 标签页被关闭

在已绑定等待窗口中重新创建对应标签页。若等待窗口也不存在，按窗口绑定恢复规则处理。

### 14.5 网页脚本失败

继续完成窗口切换；离开时即使媒体暂停失败，也恢复原窗口，并在菜单中显示非阻塞警告。

### 14.6 快捷指令卡住

超过清理预算后停止等待其完成并恢复原窗口。是否终止快捷指令进程由实现计划确认，但不得无限等待。

### 14.7 配置被 Agent 和设置窗口同时修改

配置仓库使用原子写入和版本号。发现版本冲突时，CLI 或设置界面拒绝覆盖并要求重新加载，不自动合并未知改动。

## 15. 测试计划

### 15.1 生命周期

- 两秒内完成的任务不打开 Chrome、不改变焦点；
- 长任务在延迟后进入当前 Experience；
- Stop 后清理体验并准确恢复 Codex / Claude Code 原窗口；
- PermissionRequest 立即返回对应 Session；
- 旧任务 Stop 不抢当前任务焦点；
- 安全超时恢复窗口；
- 总开关关闭时取消待切换并返回。

### 15.2 默认抖音与 Chrome

- 全新安装存在默认抖音 Experience；
- 绑定已登录抖音的普通 Chrome 窗口后复用现有登录状态；
- 不创建无痕窗口和独立 Chrome Profile；
- 重复任务复用同一抖音标签页；
- 离开时暂停媒体；
- Chrome 重启后能唯一识别现有标签页时重新绑定；
- 多 Profile 存在歧义时提示重新绑定，不静默选错账号；
- 登录过期时允许用户正常重新登录，不尝试读取凭证。

### 15.3 配置与 Skill

- 菜单可以创建、编辑、删除、排序和选择体验；
- Codex / Claude Code Skill 可以通过 CLI 完成相同配置；
- CLI JSON 输出稳定且错误可操作；
- Agent 修改配置后 App 自动刷新；
- 非法 URL、未知类型、冲突写入不会损坏配置；
- 恢复默认体验不会重复创建抖音。

### 15.4 宿主兼容

- Codex 和 Claude Code 使用各自 Hook Adapter；
- Hook stdout 不向 Agent 注入无关上下文；
- Hook 未信任、App 未运行、CLI 缺失时不阻塞宿主；
- 安装脚本识别并清理重复插件安装；
- Codex App 和 Claude Code 当前支持版本分别完成安装、信任、启动、停止和授权请求测试。

### 15.5 安全与隐私

- 配置和 Socket 权限仅当前用户可访问；
- Hook 事件不包含 Prompt 或任务内容；
- 发布包中无用户路径、Cookie、Token、浏览记录和个人配置；
- “看广告换 Token”不会产生网络请求；
- 快捷指令失败或恶意长时间运行不会阻止窗口恢复。

### 15.6 回归

保留并扩展现有核心测试，覆盖配置迁移、Session 所有权、延迟取消、安全超时、窗口恢复顺序和 CLI 校验。Debug、Release、脚本校验、插件清单校验和 ad-hoc codesign 继续进入 CI。

## 16. 成功标准

- 新用户安装后默认可以使用抖音体验；
- 已登录用户通过绑定当前普通 Chrome 窗口复用现有登录状态；
- 用户可以在菜单或通过 Codex / Claude Code 的 ThinkBreak Skill 改成任意网页，不修改 Hook 文件；
- 运行期间没有模型调用、MCP Server 或远程依赖；
- Stop、PermissionRequest 和安全超时始终优先恢复来源窗口；
- 现有 v0.1.0 配置可以无损迁移；
- 缺少权限、Chrome 状态异常或网页控制失败不会阻塞 Agent；
- 项目仍可被一句话解释为“Agent 工作时跳出去，结束时自动回来”。
