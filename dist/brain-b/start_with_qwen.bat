@echo off
chcp 65001 >nul
title S0MA-MOLMO × Qwen3-14B — GPU 全脑启动

echo.
echo ╔══════════════════════════════════════════╗
echo ║  🧠 S0MA-MOLMO × Qwen3-14B           ║
echo ║  19脑区仿生大脑 + GPU本地推理            ║
echo ╚══════════════════════════════════════════╝
echo.

cd /d "%~dp0"

taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM llama-server.exe >nul 2>&1
timeout /t 2 /nobreak >nul

node _launch.js

echo.
echo S0MA-MOLMO 已退出。
pause
