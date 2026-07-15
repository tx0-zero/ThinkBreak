param([switch]$Purge)
$ErrorActionPreference = 'SilentlyContinue'
if (Get-Command codex -ErrorAction SilentlyContinue) {
  codex plugin remove thinkbreak@thinkbreak | Out-Null
  codex plugin marketplace remove thinkbreak | Out-Null
}
if (Get-Command claude -ErrorAction SilentlyContinue) {
  claude plugin uninstall --scope user thinkbreak@thinkbreak-local | Out-Null
  claude plugin marketplace remove thinkbreak-local | Out-Null
}
if ($Purge) {
  Remove-Item -Recurse -Force (Join-Path $env:APPDATA 'ThinkBreak')
  Write-Host 'Uninstalled ThinkBreak and removed local configuration and user Recipes.'
} else {
  Write-Host 'Uninstalled ThinkBreak. Local configuration and user Recipes were preserved.'
}
