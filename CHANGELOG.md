# Changelog

All notable changes to ThinkBreak are documented here. The project follows Semantic Versioning.

## [Unreleased]

## [0.2.1] - 2026-07-19

### Changed

- Moved the canonical public repository and installation links to `github.com/tx0-zero/ThinkBreak`.
- Republished the Hook-first source package from the new repository without changing runtime behavior or local configuration formats.

## [0.2.0] - 2026-07-16

### Added

- Cross-platform Hook-first Dispatcher for macOS/Linux and Windows.
- User-editable lifecycle Recipes for waiting, return, attention, and timeout actions.
- ThinkBreak Skill for configuring Recipes through Codex or Claude Code.
- Local session files, newest-task ownership, short-task cancellation, source-window restoration, and safety timeout cleanup.
- Windows PowerShell Hook manifest, installer, uninstaller, and dispatcher entry points.
- Transparent `tx0zero-entertainment` website Recipe sample, disabled by default.

### Changed

- Waiting behavior is now defined by user Recipes instead of fixed media/reading presets.
- The default Douyin sample opens the system browser and does not inspect browser credentials or profiles.
- Release packages now contain source, plugins, scripts, tests, and project documentation rather than an application bundle.

### Removed

- Swift package, macOS menu-bar app, settings window, Chrome Apple Events controller, browser Profile management, and ad/token joke toggle UI.
- Desktop client, browser extension, MCP server, resident service, telemetry, advertising, and model-token relay behavior.

## [0.1.0] - 2026-07-13

### Added

- macOS 14+ menu-bar app with an automatic-switching master toggle.
- Editable media and reading presets with reusable Chrome tabs.
- Shared Codex and Claude Code hooks for start, permission attention, and stop events.
- Two-second short-task guard, newest-task ownership, and 30-minute safety timeout.
- Media resume/pause scripting and source-window focus restoration.
- Disabled “看广告换 Token” joke switch with no advertising or token integration.
- Portable source and release installers, uninstaller, centralized versioning, validation, CI, and release packaging.
- Chinese and English documentation, project artwork, contribution guidance, and security policy.
