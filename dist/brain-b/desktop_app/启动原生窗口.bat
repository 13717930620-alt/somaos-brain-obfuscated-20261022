@echo off
cd /d "%~dp0"
echo BrainAgent 原生桌面窗口
echo.
call npx electron main.js
pause
