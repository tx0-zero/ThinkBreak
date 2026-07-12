# ThinkBreak 人工发布检查表

## 自动检查

- [ ] `VERSION` 与目标 tag 一致。
- [ ] `./scripts/sync-version.sh` 未产生额外 diff。
- [ ] `./scripts/validate.sh` 通过（18 项核心检查、Debug/Release、shell、清单、plist、签名）。
- [ ] `./scripts/package-release.sh` 成功。
- [ ] SHA-256 校验通过，zip 内无本机路径、Token、浏览记录或个人配置。

## 全新安装与权限

- [ ] 在全新 clone 中只按 README 完成构建和安装。
- [ ] 在另一台 macOS 14+ 机器解压 Release zip，并按未公证应用流程首次打开。
- [ ] ThinkBreak 出现在辅助功能列表；授权后能够恢复准确窗口和输入焦点。
- [ ] Chrome “Allow JavaScript from Apple Events” 开启后，“测试 Chrome”成功。
- [ ] 缺少辅助功能或 Chrome 脚本权限时，hooks 仍立即退出且提示可操作。

## Codex / Claude Code 行为

- [ ] Codex 两秒内完成：不切换窗口。
- [ ] Codex 长任务：打开当前内容，结束后暂停媒体并返回。
- [ ] Claude Code 两秒内完成：不切换窗口。
- [ ] Claude Code 长任务：从原终端切出并准确返回。
- [ ] 两端的 PermissionRequest 都会立即暂停并返回对应窗口。
- [ ] 多任务交错时，旧任务 Stop 不抢走当前前台。
- [ ] 30 分钟安全时限会暂停并返回。

## 内容与发布包

- [ ] 媒体预设恢复/暂停当前网页媒体。
- [ ] 阅读预设保留滚动和阅读位置。
- [ ] 切换预设后复用原标签页，关闭标签后能重建。
- [ ] 安装、重复安装、更新、卸载均不修改 Chrome 用户数据。
- [ ] “看广告换 Token”开关禁用，且没有广告、追踪或 Token 网络请求。
- [ ] 中英文 Release Notes、zip 和 `.sha256` 均已上传。
