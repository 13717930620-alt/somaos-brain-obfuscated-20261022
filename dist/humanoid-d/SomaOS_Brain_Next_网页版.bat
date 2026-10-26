@echo off
setlocal
title SomaOS Brain Next
cd /d "%~dp0"

if not exist "node_modules" (
  echo Installing runtime dependencies...
  call npm install --no-audit --no-fund || goto :failed
)

set "SOMAOS_PORT=3002"
if defined OPENROUTER_API_KEY set "SOMAOS_OPENROUTER_KEY=%OPENROUTER_API_KEY%"

echo Starting SomaOS Brain Next server on port %SOMAOS_PORT% ...
start "SomaOS Brain Next Server" cmd /k "node src/index.js"

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
start "" http://127.0.0.1:%SOMAOS_PORT%/console
echo.
echo Server is running in the "SomaOS Brain Next Server" window.
echo Press Ctrl+C in that window for a graceful shutdown.
goto :done

:failed
echo.
echo Startup failed. Check Node.js and npm installation.
pause
exit /b 1

:done
endlocal
