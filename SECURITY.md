# Security Policy

## Supported versions

Security fixes are provided for the latest published ThinkBreak release and the current `main` branch.

## Reporting a vulnerability

请不要在公开 Issue 中披露漏洞、个人网址、Token、Prompt、窗口信息或可复现的隐私数据。

请使用 GitHub 的 **Report a vulnerability** / private security advisory 功能，说明：

- 受影响版本和操作系统；
- 影响范围和前置条件；
- 最小复现步骤；
- 如果已知，提供缓解建议。

测试时请不要访问不属于你的数据，也不要干扰第三方服务。

## Security boundaries

ThinkBreak 是本地 Hook Dispatcher。它会尽力获取前台应用和窗口信息，以便完成后返回；macOS 的窗口恢复可能需要用户自行授予辅助功能权限，但这不是安装核心的强制依赖。

ThinkBreak 不需要 API Key、OpenAI/Anthropic 账户凭证、Cookie、密码或远程后端。Recipe 由用户自己编写，任何要求提交这些秘密的 Recipe 都应视为可疑。

默认 Recipe 只打开用户指定 URL。ThinkBreak 不读取浏览器登录状态，也不上传 Prompt、回复、项目文件或 Session 内容。
