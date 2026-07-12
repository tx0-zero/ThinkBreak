# Contributing to ThinkBreak

感谢你帮助改进 ThinkBreak。Issues 和 Pull Requests 默认使用维护者审核模式。

## 开始之前

- 先搜索现有 Issue，避免重复。
- Bug 请提供 macOS、Chrome、Codex/Claude Code 版本和最小复现步骤。
- 不要提交 Token、账户信息、浏览记录、个人网址或 Application Support 配置。
- 大型功能建议先开 Issue 对齐范围；首版产品边界保持轻量。

## 本地开发

需要 macOS 14+、Xcode Command Line Tools、Swift 6 和 Google Chrome。

```bash
git clone https://github.com/Tx0Zero/ThinkBreak.git
cd ThinkBreak
./scripts/validate.sh
```

构建并安装本地版本：

```bash
./scripts/install-all.sh
```

生成发布包：

```bash
./scripts/package-release.sh
```

## Pull Request 要求

- 保持改动聚焦，说明用户可见行为和验证方式。
- 新行为需要测试；现有 18 项核心检查必须通过。
- shell 脚本需兼容 macOS 自带 Bash 3.2。
- 不引入遥测、广告 SDK 或不必要的网络请求。
- UI 改动请更新 `docs/images/` 中对应截图。
- 版本只在准备发布时通过根目录 `VERSION` 修改，并运行 `./scripts/sync-version.sh`。
- 提交前运行 `./scripts/validate.sh` 和 `git diff --check`。

提交 Pull Request 即表示你同意按项目 MIT License 提供贡献。
