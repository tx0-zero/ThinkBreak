param(
  [string]$Command = 'status',
  [string]$Arg = '',
  [string]$AgentHost = 'local',
  [string]$SessionId = ''
)
$dispatch = Join-Path (Split-Path -Parent $PSScriptRoot) 'hooks\dispatch.ps1'
$shell = Get-Command powershell.exe -ErrorAction SilentlyContinue
if (-not $shell) { $shell = Get-Command pwsh.exe -ErrorAction SilentlyContinue }
if (-not $shell) { $shell = Get-Command powershell -ErrorAction SilentlyContinue }
if (-not $shell) { $shell = Get-Command pwsh -ErrorAction SilentlyContinue }
if (-not $shell) { exit 0 }
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $dispatch, $Command, $AgentHost, $SessionId, $Arg)
& $shell.Source @arguments
exit 0
