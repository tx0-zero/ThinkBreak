# Windows helpers. All operations are best effort and return without throwing.

if (-not ('ThinkBreak.NativeMethods' -as [type])) {
  Add-Type @'
using System;
using System.Text;
using System.Diagnostics;
using System.Runtime.InteropServices;
namespace ThinkBreak {
  public static class NativeMethods {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    public const int SW_RESTORE = 9;
  }
}
'@
}

function Get-TBPlatformName { 'windows' }

function Get-TBOrigin {
  $hwnd = [ThinkBreak.NativeMethods]::GetForegroundWindow()
  $processId = 0
  [void][ThinkBreak.NativeMethods]::GetWindowThreadProcessId($hwnd, [ref]$processId)
  $title = New-Object System.Text.StringBuilder 512
  [void][ThinkBreak.NativeMethods]::GetWindowText($hwnd, $title, $title.Capacity)
  $app = ''
  try { $app = (Get-Process -Id $processId -ErrorAction Stop).ProcessName } catch {}
  @{
    SOURCE_APP = ($app -replace '[\r\n]', ' ')
    SOURCE_WINDOW = ($title.ToString() -replace '[\r\n]', ' ')
    SOURCE_PID = [string]$processId
  }
}

function Open-TBUrl([string]$Url) {
  if ([string]::IsNullOrWhiteSpace($Url)) { return }
  if ($env:THINKBREAK_TEST_OPEN_LOG) { Add-Content -LiteralPath $env:THINKBREAK_TEST_OPEN_LOG -Value $Url; return }
  try { Start-Process $Url | Out-Null } catch {}
}

function Restore-TBOrigin([string]$App, [string]$Window, [string]$SourcePid) {
  if ($env:THINKBREAK_TEST_RESTORE_LOG) {
    Add-Content -LiteralPath $env:THINKBREAK_TEST_RESTORE_LOG -Value "$App|$Window|$SourcePid"
    return
  }
  $h = [IntPtr]::Zero
  [uint32]$target = 0
  if ([uint32]::TryParse($SourcePid, [ref]$target)) {
    Get-Process -Id $target -ErrorAction SilentlyContinue | ForEach-Object {
      $h = $_.MainWindowHandle
    }
  }
  if ($h -ne [IntPtr]::Zero) {
    [void][ThinkBreak.NativeMethods]::ShowWindow($h, [ThinkBreak.NativeMethods]::SW_RESTORE)
    [void][ThinkBreak.NativeMethods]::SetForegroundWindow($h)
  }
}
