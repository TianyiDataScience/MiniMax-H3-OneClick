@echo off
setlocal
chcp 65001 >nul
echo Open: Advanced tab ^> Performance Settings ^> Advanced ^> Virtual memory.
echo Enable "Automatically manage paging file size for all drives", confirm, and restart Windows.
echo.
start "System Properties" SystemPropertiesAdvanced.exe
pause
