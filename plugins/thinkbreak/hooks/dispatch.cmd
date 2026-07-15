@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dispatch.ps1" %*
exit /b 0
