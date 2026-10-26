@echo off
title BrainAgent 桌面版
cd /d "%~dp0.."

echo.
echo   BrainAgent · 19脑区类脑认知智能体
echo   启动中...
echo.

:: 检查 node_modules
if not exist "desktop_app\node_modules" (
    echo [1/2] 首次运行，安装 Electron...
    cd desktop_app
    call npm install --save-dev electron 2>nul
    :: 如果 npm install 失败，尝试用全局 electron
    if not exist "node_modules\electron" (
        echo 使用全局 Electron...
        cd ..
    ) else (
        cd ..
    )
)

:: 启动
if exist "desktop_app\node_modules\.bin\electron.cmd" (
    start "" /B "desktop_app\node_modules\.bin\electron.cmd" "desktop_app\main.js"
) else (
    npx electron desktop_app/main.js
)

echo 桌面应用已启动，如窗口未出现请稍等...
