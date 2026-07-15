# Contributing to ThinkBreak

感谢你帮助改进 ThinkBreak。Issues 和 Pull Requests 默认使用维护者审核模式。

## 开始之前

- 先搜索现有 Issue，避免重复。
- Bug 请提供操作系统、宿主（Codex / Claude Code）、版本和最小复现步骤。
- 不要提交 Token、账户信息、Prompt、浏览记录、个人网址、Cookie 或本地配置。
- 复杂功能先开 Issue 对齐范围；核心边界保持 Hook-first、无常驻应用、无遥测。

## 本地开发

ThinkBreak 不需要 Swift、Xcode、Chrome 或桌面应用。macOS/Linux 需要 Bash；Windows 需要 PowerShell。

```bash
git clone https://github.com/Tx0Zero/ThinkBreak.git
cd ThinkBreak
./scripts/validate.sh
```

运行生命周期测试：

```bash
./tests/test_dispatch.sh
```

添加 Recipe 时，请同时提供 `recipe.env`、跨平台脚本（如果适用）和至少一个生命周期测试。Recipe 不得自动下载脚本，不得读取浏览器凭证，不得上传 Agent 数据。

## Pull Request 要求

- 保持改动聚焦，说明用户可见行为和验证方式。
- 新行为需要测试，尤其是短任务取消、并发 Owner、Recipe 失败和安全超时。
- Bash 脚本需兼容 macOS 自带 Bash 3.2；不要依赖 jq、Node 或 GNU-only 命令才能完成核心路径。
- PowerShell 脚本不得默认要求管理员权限。
- 不引入遥测、广告 SDK、账户系统、模型中转或不必要的网络请求。
- 不把具体网站逻辑写进 Dispatcher；站点行为应是可替换 Recipe。
- 提交前运行 `./scripts/validate.sh` 和 `git diff --check`。

提交 Pull Request 即表示你同意按项目 MIT License 提供贡献。
