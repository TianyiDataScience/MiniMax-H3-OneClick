@echo off
setlocal
chcp 65001 >nul
title MiniMax H3 - Windows NVIDIA Installer
set "ROOT=%~dp0"

echo ============================================================
echo MiniMax H3 / Windows NVIDIA one-click installer
echo This will download ComfyUI and about 44.4 GB of model files.
echo Keep the laptop plugged in. Downloads can be resumed.
echo ============================================================
echo.
echo IMPORTANT MODEL LICENSE NOTICE
echo The repository's MIT license covers only the installer code.
echo MiniMax H3 uses a separate community license with territorial and
echo use restrictions. EU, UK, US and South Korea are excluded unless
echo you have separate authorization from MiniMax.
echo.
echo Read before continuing:
echo %ROOT%MODEL-LICENSE-NOTICE.md
echo https://huggingface.co/MiniMaxAI/MiniMax-H3/blob/main/LICENSE
echo.
choice /C YN /N /M "I have read the model license and confirm I am authorized to download and use MiniMax H3 in my jurisdiction. Continue? [Y/N]: "
if errorlevel 2 exit /b 2

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%01-PREFLIGHT.ps1"
if errorlevel 1 (
  echo.
  echo Preflight failed. Read the red error above before continuing.
  pause
  exit /b 1
)

echo.
choice /C YN /N /M "Start the official downloads now? [Y/N]: "
if errorlevel 2 exit /b 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%02-INSTALL.ps1" -AcceptModelLicense
if errorlevel 1 (
  echo.
  echo Installation stopped. Run this file again to resume.
  pause
  exit /b 1
)

echo.
echo Running the local model and PyTorch CUDA verification...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%05-VERIFY.ps1"
if errorlevel 1 (
  echo.
  echo Installation completed, but verification failed. Run 08-COLLECT-DIAGNOSTICS.ps1.
  pause
  exit /b 1
)

echo.
echo Installation finished. Run 03-LAUNCH-STABLE.cmd for the first test.
pause
