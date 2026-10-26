@echo off
title BrainAgent (后台守护)

if not "%1"=="--hidden" (
  start "" /MIN "%~f0" --hidden
  exit /b
)

pushd "%~dp0"
if not exist "index.js" echo ERROR: index.js not found && pause && exit /b 1

:restart
taskkill /F /IM llama-server.exe >nul 2>&1
timeout /t 2 /nobreak >nul
echo [%date% %time%] 启动...
node index.js chat 2>>logs\brain_err.log
echo [%date% %time%] 退出(code:%errorlevel%)，30秒后重启...
timeout /t 30 /nobreak >nul
goto restart
