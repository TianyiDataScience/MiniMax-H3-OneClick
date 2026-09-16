@echo off
setlocal
chcp 65001 >nul
title ComfyUI H3 - Stable Mode
set "ROOT=%~dp0"
set "PORTABLE=%ROOT%runtime\ComfyUI_windows_portable"

if not exist "%PORTABLE%\python_embeded\python.exe" (
  echo ComfyUI runtime was not found next to this launcher.
  echo.
  echo Launcher: %~f0
  echo Expected: %PORTABLE%\python_embeded\python.exe
  echo.
  echo Do not run this file inside a ZIP or from projects\...\00-Backups.
  echo Extract the complete package to a permanent short English path first.
  echo.
  set "H3_LAUNCH_ROOT=%ROOT%"
  powershell.exe -NoProfile -Command "$r=[IO.Path]::GetFullPath($env:H3_LAUNCH_ROOT); $t=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()); if ($r.StartsWith($t,[StringComparison]::OrdinalIgnoreCase)) { exit 0 } else { exit 1 }" >nul 2>nul
  if not errorlevel 1 (
    echo This launcher is running from the Windows temporary directory.
    echo Close this window, extract the whole ZIP, then run 00-START-HERE.cmd.
    pause
    exit /b 1
  )
  if exist "%ROOT%00-START-HERE.cmd" (
    choice /C YN /N /M "Run the installer in this folder now? [Y/N]: "
    if errorlevel 2 exit /b 1
    call "%ROOT%00-START-HERE.cmd"
    exit /b
  )
  echo 00-START-HERE.cmd is not present beside this copied launcher.
  echo Return to the complete extracted package and run its installer.
  pause
  exit /b 1
)

echo Stable mode: dynamic offload, low-VRAM hint, 1.5 GB VRAM reserve.
echo Keep this window open while ComfyUI is running.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%11-LAUNCH.ps1" -Mode Stable
set "CODE=%ERRORLEVEL%"

if not "%CODE%"=="0" (
  echo.
  echo ComfyUI exited with code %CODE%. Copy the last 30 console lines when asking for help.
  pause
)
exit /b %CODE%
