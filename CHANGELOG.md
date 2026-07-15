# Changelog

All notable changes to ThinkBreak are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Changed

- Refactored ThinkBreak from the abandoned macOS app prototype into a cross-platform Hook-first Dispatcher and Recipe system.
- Moved waiting behavior out of fixed media/reading presets and into user-editable lifecycle scripts.
- Added Bash and PowerShell implementations, local session files, task ownership, short-task cancellation, and safety timeout cleanup.
- Added a ThinkBreak Skill so Codex or Claude Code can configure Recipes as the primary user interface.
- Kept Douyin as a default browser-opening sample while making the entertainment page transparent, replaceable, and inactive until configured.

### Removed

- Swift package, menu-bar app, settings window, Chrome Apple Events controller, browser Profile management, and ad/token joke toggle UI.

## [0.1.0] - 2026-07-16

### Added

- Codex and Claude Code Hook manifests for `UserPromptSubmit`, `PermissionRequest`, and `Stop`.
- Configurable Recipe contract with `on-wait`, `on-return`, `on-attention`, and `on-timeout` events.
- macOS/Linux Bash Dispatcher and Windows PowerShell Dispatcher.
- Local-only configuration, session state, newest-task foreground ownership, and safety timeout.
- Douyin example, transparent entertainment-page example, and custom Recipe template.
- Chinese and English documentation, MIT License, contribution guidance, security policy, and lifecycle tests.
- Disabled-by-design future “watch ads for model credits” direction with no advertising, account, telemetry, or token service.
