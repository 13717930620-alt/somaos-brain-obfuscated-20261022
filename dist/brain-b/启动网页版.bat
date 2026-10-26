@echo off
chcp 65001 >nul
title SomaOS Brain Web Panel

echo.
echo  ========================================
echo    SomaOS v13 Brain Web Panel
echo  ========================================
echo.

cd /d "%~dp0"

:: Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   [ERROR] Node.js not found, please install from https://nodejs.org
    pause
    exit /b 1
)

:: Check key files
if not exist "web_dialog.js" (
    echo   [ERROR] web_dialog.js not found!
    pause
    exit /b 1
)

if not exist ".env" (
    echo   [WARN] .env file not found
    echo   LLM_MODE=api> .env
    echo   LLM_BASE_URL=https://api.deepseek.com>> .env
    echo   LLM_API_KEY=sk-your-key-here>> .env
    echo   LLM_MODEL=deepseek-chat>> .env
    echo   BRAIN_WEB_PORT=3001>> .env
    echo   [INFO] .env template created
    echo   [WARN] Please edit .env file, fill in your DeepSeek API Key, then re-run this file!
    start notepad .env
    pause
    exit /b 1
)

echo   [INFO] Starting...
echo   [WEB] http://localhost:3001
echo   [INFO] First launch takes 30-90 seconds to init, please wait for browser to open automatically...
echo.

:: Reset errorlevel before launching node
set errorlevel=0

:: Launch (launch.js will auto-open browser when web server is ready)
node scripts/launch.js

echo.
echo   [INFO] launch.js exited with code %errorlevel%
pause
