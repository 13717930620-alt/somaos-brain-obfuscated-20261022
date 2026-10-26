@echo off
chcp 65001 >nul
title S0MA-MOLMO — Gemma4 GPU 智能体

echo.
echo ╔══════════════════════════════════════════╗
echo ║  🧠 S0MA-MOLMO 智能体 v3.0              ║
echo ║  Qwen3-14B GPU + 19脑区 + Web面板      ║
echo ╚══════════════════════════════════════════╝
echo.
echo   _launch.js 管理完整启动流程:
echo   0. 环境检查 + 按端口清理旧进程
echo   1. 启动 Gemma4 GPU 引擎 (端口18080)
echo   2. 大脑初始化 (19脑区)
echo   3. Web面板 (端口3001)
echo   4. 健康验证 + 守护模式
echo.

cd /d "%~dp0"
node _launch.js

echo.
echo S0MA-MOLMO 已退出。
pause
