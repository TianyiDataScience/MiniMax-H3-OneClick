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

powershell.exe -NoProfile -Command "try { $r=Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 2; if ($r.devices) { exit 0 } }; exit 1" >nul 2>nul
if not errorlevel 1 (
  echo ComfyUI is already running at http://127.0.0.1:8188
  start "" "http://127.0.0.1:8188"
  exit /b 0
)

if exist "%ROOT%runtime\selected-gpu.txt" set /p "CUDA_VISIBLE_DEVICES="<"%ROOT%runtime\selected-gpu.txt"
if defined CUDA_VISIBLE_DEVICES echo Using selected physical NVIDIA GPU index %CUDA_VISIBLE_DEVICES%.

if not exist "%ROOT%runtime\logs" mkdir "%ROOT%runtime\logs"

echo Balanced mode: use only after Stable Mode has generated successfully.
echo Do not use this mode while OBS is using the RTX GPU.

pushd "%PORTABLE%"
"python_embeded\python.exe" -s "ComfyUI\main.py" --windows-standalone-build --auto-launch --reserve-vram 0.8 --preview-method none --verbose INFO "%ROOT%runtime\logs\comfyui-balanced.log"
set "CODE=%ERRORLEVEL%"
popd

if not "%CODE%"=="0" pause
exit /b %CODE%
