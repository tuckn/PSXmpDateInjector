
@echo off
setlocal EnableExtensions
set "_ROOT=%~dp0.."
set "_SCRIPT=%_ROOT%\scripts\AddImageXmpDateMetadata.ps1"

where pwsh.exe >nul 2>&1
if not errorlevel 1 (
  pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%_SCRIPT%" -Verbose %*
) else (
  powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%_SCRIPT%" -Verbose %*
)
endlocal
