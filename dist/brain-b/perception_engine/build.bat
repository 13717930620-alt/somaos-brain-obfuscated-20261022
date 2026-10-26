@echo off
chcp 65001 >nul
cd /d %~dp0
echo ============================================
echo   Perception Engine Cpp Native Build
echo ============================================
echo.
call npm install --save node-addon-api 2>nul
call npx node-gyp configure 2>&1
call npx node-gyp build 2>&1
if exist build\Release\perception_engine.node (
  echo [OK] Native addon compiled
) else (
  echo [NOTE] No C++ toolchain - Python fallback active
)
pause
