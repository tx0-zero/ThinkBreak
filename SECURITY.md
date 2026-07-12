# Security Policy

## Supported versions

Security fixes are provided for the latest published ThinkBreak release and the current `main` branch.

## Reporting a vulnerability

请不要在公开 Issue 中披露漏洞、个人网址、Token、窗口信息或可复现的隐私数据。

Use GitHub's **Report a vulnerability** / private security advisory feature in the `Tx0Zero/ThinkBreak` repository. Include:

- affected version and macOS version;
- impact and prerequisites;
- minimal reproduction steps;
- suggested mitigation, if known.

The maintainer will acknowledge a report when available, investigate it privately, and coordinate disclosure after a fix or mitigation is ready. Please do not access data that is not yours or disrupt third-party services while testing.

## Security boundaries

ThinkBreak controls local windows and Chrome through macOS Accessibility and Apple Events. It does not need API keys, OpenAI/Anthropic account credentials, or a remote backend. A request for those secrets should be treated as suspicious.
