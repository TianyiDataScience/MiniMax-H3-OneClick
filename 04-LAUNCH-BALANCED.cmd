@echo off
setlocal
chcp 65001 >nul
title ComfyUI H3 - Balanced Mode
set "ROOT=%~dp0"
set "PORTABLE=%ROOT%runtime\ComfyUI_windows_portable"

if not exist "%PORTABLE%\python_embeded\python.exe" (
  echo ComfyUI runtime was not found next to this launcher.
  echo Launcher: %~f0
  echo Expected: %PORTABLE%\python_embeded\python.exe
  echo Do not run this file inside a ZIP or from a backup directory.
  pause
  exit /b 1
)

echo Balanced mode: use only after Stable Mode has generated successfully.
echo Do not use this mode while OBS is using the RTX GPU.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%11-LAUNCH.ps1" -Mode Balanced
set "CODE=%ERRORLEVEL%"

if not "%CODE%"=="0" pause
exit /b %CODE%
