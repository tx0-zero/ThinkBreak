# ThinkBreak 人工发布检查表

## 自动检查

- [ ] `VERSION` 与目标 tag 一致。
- [ ] `./scripts/validate.sh` 通过。
- [ ] `./tests/test_dispatch.sh` 通过。
- [ ] Bash 脚本通过 `bash -n`；PowerShell 文件完成静态检查（CI 有 PowerShell 时执行）。
- [ ] Hook 清单、Plugin manifest、Recipe manifest 都是合法 JSON / key-value 格式。
- [ ] 发布包和 git 历史中没有用户路径、Token、Prompt、浏览记录或个人配置。

## 全新安装

- [ ] 在全新 clone 中只按 README 完成安装。
- [ ] macOS/Linux 不会启动应用或后台服务。
- [ ] Windows 可以使用 `hooks.windows.json` 和 `dispatch.ps1`。
- [ ] 缺少辅助功能权限、浏览器或来源窗口时，Hook 仍正常退出。
- [ ] 重复安装、更新和卸载不会删除 Codex、Claude Code 或浏览器数据。

## Codex / Claude Code 行为

- [ ] 任务在延迟内完成：不执行 `on-wait`，不改变焦点。
- [ ] 长任务：执行选中的 Recipe。
- [ ] `Stop`：执行 `on-return` 并返回来源窗口。
- [ ] `PermissionRequest`：立即执行 `on-attention` 并返回。
- [ ] 旧任务结束不会抢走最新任务的 Owner。
- [ ] Recipe 失败或超时不会阻塞宿主 Hook。
- [ ] 安全时限会执行 `on-timeout` 并清理 Owner。

## 内容和未来页面

- [ ] 抖音仅作为默认样板，使用用户默认浏览器已有登录会话。
- [ ] B 站、小说、音乐和用户网站都可以通过复制 Recipe 配置。
- [ ] 官方娱乐 Recipe 默认空 URL / 不选中，用户确认后才启用。
- [ ] “看广告换额度”只在文档和用户网站中作为玩梗/兴趣收集，不包含广告 SDK、账户、奖励或模型中转。
