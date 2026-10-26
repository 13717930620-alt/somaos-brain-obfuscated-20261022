@echo off
chcp 65001 >nul
setlocal
title SomaOS Brain Next - Full Local Stack
cd /d "%~dp0"

set "SOMAOS_PORT=3002"
set "SOMAOS_LOCAL_LLM_URL=http://127.0.0.1:18080/v1"
set "SOMAOS_LOCAL_VLM_URL=http://127.0.0.1:18081/v1"
set "SOMAOS_DATA_PLANE_PORT=3101"
set "SOMAOS_DATA_PLANE_URL=http://127.0.0.1:3101"

call start_local_inference.bat
if errorlevel 1 goto :failed

echo Starting local data-plane bridge on http://127.0.0.1:%SOMAOS_DATA_PLANE_PORT% ...
start "SomaOS Data Plane" /MIN cmd /c "node dataplane\local_bridge.js"

echo Waiting for local model warm-up...
timeout /t 10 /nobreak >nul

echo Starting SomaOS Brain Next on http://127.0.0.1:%SOMAOS_PORT%/console
start "SomaOS Brain Next" cmd /k "node src/index.js"

rem Browser opens only after the server passes its health check (max 60s wait)
set /a tries=0
:waitloop
set /a tries+=1
if %tries% gtr 60 goto :openbrowser
curl -s -o nul -m 2 http://127.0.0.1:%SOMAOS_PORT%/health
if errorlevel 1 (
  timeout /t 1 /nobreak >nul 2>&1
  goto :waitloop
)

:openbrowser
start "" "http://127.0.0.1:%SOMAOS_PORT%/console"
echo.
echo Server is running in the "SomaOS Brain Next" window.
echo Close that window (or press Ctrl+C in it) to stop the brain.
goto :done

:failed
echo.
echo Failed to start the full local stack.
pause
exit /b 1

:done
endlocal
