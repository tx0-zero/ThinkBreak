$Script:TBPluginRoot = $env:THINKBREAK_PLUGIN_ROOT
if ([string]::IsNullOrWhiteSpace($Script:TBPluginRoot)) {
  $Script:TBPluginRoot = Split-Path -Parent $PSScriptRoot
}
. (Join-Path $PSScriptRoot 'platform-windows.ps1')

function Get-TBHome {
  if (-not [string]::IsNullOrWhiteSpace($env:THINKBREAK_HOME)) { return $env:THINKBREAK_HOME }
  if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) { return (Join-Path $env:APPDATA 'ThinkBreak') }
  return (Join-Path $HOME '.thinkbreak')
}
function Get-TBConfigFile { Join-Path (Get-TBHome) 'config.env' }
function Get-TBSessionsDir { Join-Path (Get-TBHome) 'sessions' }
function Get-TBCurrentDir { Join-Path (Get-TBHome) 'current' }
function Initialize-TBHome {
  New-Item -ItemType Directory -Force -Path (Get-TBHome), (Get-TBSessionsDir), (Get-TBCurrentDir), (Join-Path (Get-TBHome) 'recipes') | Out-Null
}

function Get-TBKey([string]$File, [string]$Key, [string]$Default = '') {
  if (-not (Test-Path -LiteralPath $File)) { return $Default }
  foreach ($line in (Get-Content -LiteralPath $File -ErrorAction SilentlyContinue)) {
    if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
    if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$") {
      $value = $Matches[1].Trim()
      if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') -or ($value[0] -eq "'" -and $value[$value.Length - 1] -eq "'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      return $value
    }
  }
  return $Default
}

function Set-TBKey([string]$File, [string]$Key, [string]$Value) {
  $directory = Split-Path -Parent $File
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $lines = @()
  $found = $false
  if (Test-Path -LiteralPath $File) {
    foreach ($line in Get-Content -LiteralPath $File) {
      if ($line -match "^\s*$([regex]::Escape($Key))\s*=") {
        if (-not $found) {
          $lines += "$Key=$Value"
          $found = $true
        }
      } else {
        $lines += $line
      }
    }
  }
  if (-not $found) { $lines += "$Key=$Value" }
  $temporary = "$File.$PID.tmp"
  Set-Content -LiteralPath $temporary -Value $lines -Encoding UTF8
  Move-Item -Force $temporary $File
}

function Get-TBSafeId([string]$Id) {
  if ([string]::IsNullOrWhiteSpace($Id)) { return '' }
  $safe = [regex]::Replace($Id, '[^A-Za-z0-9._-]', '_')
  if ($safe.Length -gt 96) { $safe = $safe.Substring(0, 96) }
  return $safe
}
function Get-TBSessionKey([string]$AgentHost, [string]$Id) { "${AgentHost}__$((Get-TBSafeId $Id))" }
function Get-TBSessionFile([string]$AgentHost, [string]$Id) { Join-Path (Get-TBSessionsDir) "$(Get-TBSessionKey $AgentHost $Id).env" }
function Get-TBCurrentFile([string]$AgentHost) { Join-Path (Get-TBCurrentDir) (Get-TBSafeId $AgentHost) }
function Get-TBCurrentKey([string]$AgentHost) {
  $file = Get-TBCurrentFile $AgentHost
  if (Test-Path -LiteralPath $file) { return (Get-Content -LiteralPath $file -Raw).Trim() }
  return ''
}
function Set-TBCurrent([string]$AgentHost, [string]$Key) {
  $file = Get-TBCurrentFile $AgentHost
  $temporary = "$file.$PID.tmp"
  Set-Content -LiteralPath $temporary -Value $Key -Encoding UTF8
  Move-Item -Force $temporary $file
}
function Clear-TBCurrentIf([string]$AgentHost, [string]$Key) {
  if ((Get-TBCurrentKey $AgentHost) -eq $Key) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Get-TBCurrentFile $AgentHost)
  }
}
function Write-TBSession([string]$File, [hashtable]$Values) {
  $temporary = "$File.$PID.tmp"
  $lines = @()
  foreach ($key in $Values.Keys) {
    $value = [string]$Values[$key] -replace '[\r\n]', ' '
    $lines += "$key=$value"
  }
  Set-Content -LiteralPath $temporary -Value $lines -Encoding UTF8
  Move-Item -Force $temporary $File
}
function Get-TBConfigValue([string]$Key, [string]$Default) { Get-TBKey (Get-TBConfigFile) $Key $Default }
function Get-TBRecipeId { Get-TBConfigValue 'RECIPE_ID' 'douyin-example' }
function Get-TBRecipeDir([string]$Id) {
  if ($Id -notmatch '^[A-Za-z0-9._-]{1,96}$') { return $null }
  $user = Join-Path (Join-Path (Get-TBHome) 'recipes') $Id
  $builtin = Join-Path (Join-Path $Script:TBPluginRoot 'recipes') $Id
  if (Test-Path -LiteralPath $user -PathType Container) { return $user }
  if (Test-Path -LiteralPath $builtin -PathType Container) { return $builtin }
  return $null
}

function Get-TBPowerShell {
  foreach ($name in @('powershell.exe', 'pwsh.exe', 'powershell', 'pwsh')) {
    $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
  }
  return $null
}
function ConvertTo-TBProcessArgument([string]$Value) {
  if ($null -eq $Value) { return '""' }
  return '"' + ($Value -replace '"', '\"') + '"'
}
function Write-TBWarning([string]$Message) { [Console]::Error.WriteLine("[ThinkBreak] $Message") }

function Run-TBRecipe([string]$TbEvent, [string]$RecipeDir, [string]$SessionFile) {
  $script = Join-Path $RecipeDir "on-$TbEvent.ps1"
  if (-not (Test-Path -LiteralPath $script)) { return }
  $shell = Get-TBPowerShell
  if ([string]::IsNullOrWhiteSpace($shell)) {
    Write-TBWarning 'PowerShell was not found; skipped the Windows Recipe action.'
    return
  }

  # Export recipe.env first, then overwrite the reserved runtime variables.
  $recipeEnv = Join-Path $RecipeDir 'recipe.env'
  if (Test-Path -LiteralPath $recipeEnv) {
    foreach ($line in Get-Content -LiteralPath $recipeEnv) {
      if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') -or ($value[0] -eq "'" -and $value[$value.Length - 1] -eq "'"))) {
          $value = $value.Substring(1, $value.Length - 2)
        }
        Set-Item -Path "Env:$($Matches[1])" -Value $value
      }
    }
  }
  $env:THINKBREAK_EVENT = $TbEvent
  $env:THINKBREAK_HOST = Get-TBKey $SessionFile 'HOST'
  $env:THINKBREAK_SESSION_ID = Get-TBKey $SessionFile 'SESSION_ID'
  $env:THINKBREAK_PLATFORM = Get-TBPlatformName
  $env:THINKBREAK_SOURCE_APP = Get-TBKey $SessionFile 'SOURCE_APP'
  $env:THINKBREAK_SOURCE_WINDOW = Get-TBKey $SessionFile 'SOURCE_WINDOW'
  $env:THINKBREAK_SOURCE_PID = Get-TBKey $SessionFile 'SOURCE_PID'
  $env:THINKBREAK_RECIPE_ID = Get-TBKey $SessionFile 'RECIPE_ID'
  $env:THINKBREAK_RECIPE_DIR = $RecipeDir
  $env:THINKBREAK_WAIT_URL = Get-TBKey $recipeEnv 'RECIPE_WAIT_URL'
  $env:THINKBREAK_HOME = Get-TBHome

  $arguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (ConvertTo-TBProcessArgument $script)
  ) -join ' '
  try {
    $process = Start-Process -FilePath $shell -WindowStyle Hidden -PassThru -ArgumentList $arguments
    $timeout = 8
    $configuredTimeout = Get-TBConfigValue 'ACTION_TIMEOUT_SECONDS' '4'
    if ($configuredTimeout -match '^\d+$') { $timeout = [int]$configuredTimeout }
    if (-not $process.WaitForExit($timeout * 1000)) {
      try { $process.Kill() } catch {}
      Write-TBWarning "Recipe $TbEvent exceeded ${timeout}s; continuing without blocking the Agent."
    }
  } catch {
    Write-TBWarning "Recipe $TbEvent could not start; continuing without blocking the Agent."
  }
}

function Get-TBOriginSafe { try { return Get-TBOrigin } catch { return @{ SOURCE_APP = ''; SOURCE_WINDOW = ''; SOURCE_PID = '' } } }
function Start-TBWorker([string]$AgentHost, [string]$Id) {
  $dispatch = Join-Path $Script:TBPluginRoot 'hooks\dispatch.ps1'
  $shell = Get-TBPowerShell
  if ([string]::IsNullOrWhiteSpace($shell)) { return }
  $arguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (ConvertTo-TBProcessArgument $dispatch),
    (ConvertTo-TBProcessArgument 'worker'), (ConvertTo-TBProcessArgument $AgentHost), (ConvertTo-TBProcessArgument $Id)
  ) -join ' '
  try { Start-Process -FilePath $shell -WindowStyle Hidden -ArgumentList $arguments | Out-Null } catch {}
}
function New-TBSession([string]$AgentHost, [string]$Id) {
  $recipe = Get-TBRecipeId
  $origin = Get-TBOriginSafe
  $values = @{
    SESSION_ID = $Id
    HOST = $AgentHost
    STATE = 'pending'
    RECIPE_ID = $recipe
    CREATED_AT = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  }
  foreach ($key in $origin.Keys) { $values[$key] = $origin[$key] }
  Write-TBSession (Get-TBSessionFile $AgentHost $Id) $values
  Set-TBCurrent $AgentHost (Get-TBSessionKey $AgentHost $Id)
}
function Start-TBSession([string]$AgentHost, [string]$Id) {
  if ((Get-TBConfigValue 'ENABLED' 'true') -ne 'true') { return }
  if ([string]::IsNullOrWhiteSpace($Id)) { $Id = "$AgentHost-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())-$PID" }
  $Id = Get-TBSafeId $Id
  $recipeId = Get-TBRecipeId
  if (-not (Get-TBRecipeDir $recipeId)) { Write-TBWarning "Recipe not found: $recipeId"; return }
  New-TBSession $AgentHost $Id
  Start-TBWorker $AgentHost $Id
}
function Finish-TBSession([string]$TbEvent, [string]$AgentHost, [string]$Id) {
  $file = Get-TBSessionFile $AgentHost $Id
  $key = Get-TBSessionKey $AgentHost $Id
  if (-not (Test-Path -LiteralPath $file) -or (Get-TBCurrentKey $AgentHost) -ne $key) {
    Remove-Item -Force -ErrorAction SilentlyContinue $file
    return
  }
  $state = Get-TBKey $file 'STATE' 'pending'
  $recipe = Get-TBRecipeDir (Get-TBKey $file 'RECIPE_ID' (Get-TBRecipeId))
  Set-TBKey $file STATE 'ended'
  Clear-TBCurrentIf $AgentHost $key
  if ($state -eq 'active') {
    if ($recipe) { Run-TBRecipe $TbEvent $recipe $file }
    if ([string]::IsNullOrWhiteSpace((Get-TBCurrentKey $AgentHost))) {
      Restore-TBOrigin (Get-TBKey $file 'SOURCE_APP') (Get-TBKey $file 'SOURCE_WINDOW') (Get-TBKey $file 'SOURCE_PID')
    }
  }
  Remove-Item -Force -ErrorAction SilentlyContinue $file
}
function Invoke-TBWorker([string]$AgentHost, [string]$Id) {
  $file = Get-TBSessionFile $AgentHost $Id
  $key = Get-TBSessionKey $AgentHost $Id
  $delay = 2
  $configuredDelay = Get-TBConfigValue 'DELAY_SECONDS' '2'
  if ($configuredDelay -match '^\d+$') { $delay = [int]$configuredDelay }
  Start-Sleep -Seconds $delay
  if (-not (Test-Path -LiteralPath $file) -or (Get-TBCurrentKey $AgentHost) -ne $key -or (Get-TBConfigValue 'ENABLED' 'true') -ne 'true') {
    Clear-TBCurrentIf $AgentHost $key
    Remove-Item -Force -ErrorAction SilentlyContinue $file
    return
  }
  $recipe = Get-TBRecipeDir (Get-TBKey $file 'RECIPE_ID' (Get-TBRecipeId))
  if (-not $recipe) {
    Clear-TBCurrentIf $AgentHost $key
    Remove-Item -Force -ErrorAction SilentlyContinue $file
    return
  }
  if ((Get-TBKey (Join-Path $recipe 'recipe.env') 'RECIPE_ENABLED' 'true') -ne 'true') {
    Clear-TBCurrentIf $AgentHost $key
    Remove-Item -Force -ErrorAction SilentlyContinue $file
    return
  }
  Set-TBKey $file STATE 'active'
  Run-TBRecipe 'wait' $recipe $file
  $timeout = 1800
  $configuredTimeout = Get-TBConfigValue 'SAFETY_TIMEOUT_SECONDS' '1800'
  if ($configuredTimeout -match '^\d+$') { $timeout = [int]$configuredTimeout }
  $deadline = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $timeout
  while ((Test-Path -LiteralPath $file) -and (Get-TBCurrentKey $AgentHost) -eq $key) {
    if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $deadline) {
      Finish-TBSession 'timeout' $AgentHost $Id
      Write-TBWarning 'Safety timeout reached; returned to the source window.'
      return
    }
    Start-Sleep -Seconds 1
  }
}
function Initialize-TBConfig {
  Initialize-TBHome
  $file = Get-TBConfigFile
  if (-not (Test-Path -LiteralPath $file)) {
    Set-Content -LiteralPath $file -Value @(
      '# ThinkBreak local configuration'
      'ENABLED=true'
      'RECIPE_ID=douyin-example'
      'DELAY_SECONDS=2'
      'SAFETY_TIMEOUT_SECONDS=1800'
      'ACTION_TIMEOUT_SECONDS=4'
    ) -Encoding UTF8
  }
  Write-Output "ThinkBreak config: $file"
}
function Invoke-TBDispatch([string]$TbEvent, [string]$AgentHost, [string]$Id, [string]$Arg) {
  Initialize-TBHome
  switch ($TbEvent) {
    'start' { Start-TBSession $AgentHost $Id }
    'worker' { Invoke-TBWorker $AgentHost $Id }
    'stop' {
      if (-not $Id) {
        $current = Get-TBCurrentKey $AgentHost
        if ($current) { $Id = $current.Substring($current.IndexOf('__') + 2) }
      }
      if ($Id) { Finish-TBSession 'return' $AgentHost $Id }
    }
    'attention' {
      if (-not $Id) {
        $current = Get-TBCurrentKey $AgentHost
        if ($current) { $Id = $current.Substring($current.IndexOf('__') + 2) }
      }
      if ($Id) { Finish-TBSession 'attention' $AgentHost $Id }
    }
    'enable' { Set-TBKey (Get-TBConfigFile) ENABLED 'true' }
    'disable' { Set-TBKey (Get-TBConfigFile) ENABLED 'false' }
    'use' { if (Get-TBRecipeDir $Arg) { Set-TBKey (Get-TBConfigFile) RECIPE_ID $Arg } }
    'set-delay' { if ($Arg -match '^\d+$') { Set-TBKey (Get-TBConfigFile) DELAY_SECONDS $Arg } }
    'set-timeout' { if ($Arg -match '^\d+$') { Set-TBKey (Get-TBConfigFile) SAFETY_TIMEOUT_SECONDS $Arg } }
    'status' {
      Write-Output "enabled=$(Get-TBConfigValue ENABLED true)"
      Write-Output "recipe=$(Get-TBRecipeId)"
      Write-Output "delay_seconds=$(Get-TBConfigValue DELAY_SECONDS 2)"
      Write-Output "safety_timeout_seconds=$(Get-TBConfigValue SAFETY_TIMEOUT_SECONDS 1800)"
      Write-Output "home=$(Get-TBHome)"
    }
    'validate' {
      $recipeId = Get-TBRecipeId
      $directory = Get-TBRecipeDir $recipeId
      if ($directory) { Write-Output "Recipe $recipeId is valid ($directory)" } else { Write-TBWarning "Recipe not found: $recipeId" }
    }
    'test' { Start-TBSession $AgentHost "test-$PID" }
    'init' { Initialize-TBConfig }
  }
}
