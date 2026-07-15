$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Plugin = Join-Path $Root 'plugins\thinkbreak'
& (Join-Path $Plugin 'bin\thinkbreak.ps1') init
Write-Host 'ThinkBreak core files are ready.'
Write-Host 'For Windows, use plugins\thinkbreak\hooks\hooks.windows.json in the Codex or Claude Code Hook configuration.'
if (Get-Command codex -ErrorAction SilentlyContinue) { Write-Host 'Codex CLI found. Register the local plugin using the Codex plugin marketplace flow.' } else { Write-Host 'Codex CLI not found; skipped Codex registration.' }
if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Host 'Claude Code CLI found. Register the local plugin using the Claude Code marketplace flow.' } else { Write-Host 'Claude Code CLI not found; skipped Claude Code registration.' }
