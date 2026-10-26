@echo off
chcp 65001 >nul
title BrainAgent 自动安装
echo ============================================
echo   🧠 BrainAgent 持续运行安装程序
echo   安装后每次开机自动启动,崩溃自动重启
echo ============================================
echo.

set BRAIN_DIR=%~dp0

echo [1/3] 配置已完成 (run_brain.vbs已存在)
echo.

echo [2/3] 注册Windows计划任务(开机自启)...
schtasks /create /tn "BrainAgent" /tr "wscript.exe ""%BRAIN_DIR%run_brain.vbs""" /sc onlogon /ru %USERNAME% /f

echo [3/3] 启动大脑引擎...
start "" wscript.exe "%BRAIN_DIR%run_brain.vbs"

echo.
echo ✅ 安装完成!
echo   - 开机自动启动: 是
echo   - 崩溃自动重启: 是 (start_brain.bat无限循环)
echo   - Web面板:      http://localhost:3001
echo   - 日志位置:      %BRAIN_DIR%.brain-memory\
echo.
echo 按任意键关闭本窗口...
pause >nul
