param()
if ($env:THINKBREAK_WAIT_URL) { try { Start-Process $env:THINKBREAK_WAIT_URL | Out-Null } catch {} }
