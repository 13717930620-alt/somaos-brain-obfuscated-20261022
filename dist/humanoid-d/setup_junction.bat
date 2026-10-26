@echo off
setlocal
set "JUNCTION_PATH=C:\somaos_test"
set "PROJECT_PATH=%~dp0"
set "PROJECT_PATH=%PROJECT_PATH:~0,-1%"

if exist "%JUNCTION_PATH%\llama\llama.exe" (
    exit /b 0
)

if exist "%JUNCTION_PATH%" (
    rmdir "%JUNCTION_PATH%" 2>nul
)

mklink /J "%JUNCTION_PATH%" "%PROJECT_PATH%" >nul 2>&1
if errorlevel 1 (
    echo [WARN] Failed to create junction at %JUNCTION_PATH%
    exit /b 1
)

echo [OK] Junction created: %JUNCTION_PATH% -^> %PROJECT_PATH%
exit /b 0