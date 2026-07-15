param(
  [string]$TbEvent,
  [string]$AgentHost = 'unknown',
  [string]$SessionId = '',
  [string]$Argument = ''
)
$ErrorActionPreference = 'SilentlyContinue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir '..\lib\runtime.ps1')
if ($AgentHost -eq 'unknown') {
  if ($env:CODEX_PLUGIN_ROOT) { $AgentHost = 'codex' }
  elseif ($env:CLAUDE_PLUGIN_ROOT) { $AgentHost = 'claude-code' }
}
if (-not $SessionId -and $TbEvent -notin @('worker','status','enable','disable','use','set-delay','set-timeout','validate','test','init')) {
  try {
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $SessionId = $payload.session_id
    if (-not $SessionId) { $SessionId = $payload.sessionId }
  } catch {}
}
Invoke-TBDispatch $TbEvent $AgentHost $SessionId $Argument
exit 0
