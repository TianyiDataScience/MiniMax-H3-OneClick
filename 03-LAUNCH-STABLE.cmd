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
  echo Extract the complete package, run 00-START-HERE.cmd there, and then
  echo use the 03-LAUNCH-STABLE.cmd from that same installed folder.
  pause
  exit /b 1
)

powershell.exe -NoProfile -Command "try { $r=Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 2; if ($r.devices) { exit 0 } }; exit 1" >nul 2>nul
if not errorlevel 1 (
  echo ComfyUI is already running at http://127.0.0.1:8188
  start "" "http://127.0.0.1:8188"
  exit /b 0
)

if exist "%ROOT%runtime\selected-gpu.txt" set /p "CUDA_VISIBLE_DEVICES="<"%ROOT%runtime\selected-gpu.txt"
if defined CUDA_VISIBLE_DEVICES echo Using selected physical NVIDIA GPU index %CUDA_VISIBLE_DEVICES%.

if not exist "%ROOT%runtime\logs" mkdir "%ROOT%runtime\logs"

echo Stable mode: dynamic offload, low-VRAM hint, 1.5 GB VRAM reserve.
echo Keep this window open while ComfyUI is running.

pushd "%PORTABLE%"
"python_embeded\python.exe" -s "ComfyUI\main.py" --windows-standalone-build --auto-launch --lowvram --reserve-vram 1.5 --disable-pinned-memory --preview-method none --verbose INFO "%ROOT%runtime\logs\comfyui-stable.log"
set "CODE=%ERRORLEVEL%"
popd

if not "%CODE%"=="0" (
  echo.
  echo ComfyUI exited with code %CODE%. Copy the last 30 console lines when asking for help.
  pause
)
exit /b %CODE%
