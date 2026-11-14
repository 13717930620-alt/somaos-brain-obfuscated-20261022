@echo off
cd /d "%~dp0.."
title BrainAgent 窗口

set EDGE=
if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" set EDGE=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" set EDGE=C:\Program Files\Microsoft\Edge\Application\msedge.exe
if "%EDGE%"=="" set EDGE=msedge.exe

echo 正在启动 BrainAgent 桌面窗口...
echo.

powershell -Command "try {$r=Invoke-WebRequest -Uri 'http://localhost:3003/' -TimeoutSec 2;exit 0}catch{exit 1}"
if errorlevel 1 (
    echo 服务未运行，正在启动...
    start "" /MIN "一键启动.bat"
    echo 等待服务就绪（约15秒）...
    timeout /t 15 /nobreak >nul
)

start "" "%EDGE%" --app=http://localhost:3003 --window-size=1200,800
echo 窗口已打开，如果未出现请检查 Edge 是否安装
pause
