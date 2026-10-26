@echo off
chcp 65001 >nul
title SomaOS - Local Inference Services

cd /d "%~dp0"

echo ============================================================
echo   SomaOS - Local Inference Services Launcher
echo ============================================================
echo.

:: Check for models
if not exist "models\llm\qwen3-14b-instruct-q4_k_m.gguf" (
    echo [WARN] LLM model not found: models\llm\qwen3-14b-instruct-q4_k_m.gguf
    echo   Run: python scripts\download_all_models.pyc
    echo   Then re-run this script.
)
if not exist "models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf" (
    echo [WARN] VLM model not found: models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf
)
if not exist "models\speech\ggml-large-v3.bin" (
    echo [WARN] STT model not found: models\speech\ggml-large-v3.bin
)

echo.

:: Clean up existing process on port 18080
echo [1/4] Cleaning old LLM process on port 18080...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :18080 ^| findstr LISTENING 2^>nul') do (
    taskkill /PID %%a /F >nul 2>&1
    echo   Stopped PID %%a
)

:: Clean up existing process on port 18081
echo [2/4] Cleaning old VLM process on port 18081...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :18081 ^| findstr LISTENING 2^>nul') do (
    taskkill /PID %%a /F >nul 2>&1
    echo   Stopped PID %%a
)

echo.
echo [3/4] Starting LLM Service (Qwen3-14B) on port 18080...

:: Start LLM (Qwen3-14B) on port 18080
if exist "models\llm\qwen3-14b-instruct-q4_k_m.gguf" (
    start "SomaOS-LLM" /MIN llama\llama-server.exe ^
        -m models\llm\qwen3-14b-instruct-q4_k_m.gguf ^
        --port 18080 ^
        --host 127.0.0.1 ^
        -ngl 99 ^
        -c 16384 ^
        -t 6 ^
        -b 2048 ^
        --mlock
    echo   LLM service started (port 18080)
) else (
    echo   [SKIP] LLM model not found
)

:: Start VLM (Qwen3-VL-8B) on port 18081
echo [4/4] Starting VLM Service (Qwen3-VL-8B) on port 18081...

if exist "models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf" (
    if exist "models\vlm\mmproj-qwen3-vl-8b-f16.gguf" (
        start "SomaOS-VLM" /MIN llama\llama-server.exe ^
            -m models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf ^
            --mmproj models\vlm\mmproj-qwen3-vl-8b-f16.gguf ^
            --port 18081 ^
            --host 127.0.0.1 ^
            -ngl 99 ^
            -c 8192 ^
            -t 4 ^
            -b 1024 ^
            --mlock
        echo   VLM service started (port 18081)
    ) else (
        echo   [WARN] VLM mmproj not found, starting VLM in text-only mode
        start "SomaOS-VLM" /MIN llama\llama-server.exe ^
            -m models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf ^
            --port 18081 ^
            --host 127.0.0.1 ^
            -ngl 99 ^
            -c 8192 ^
            -t 4 ^
            -b 1024 ^
            --mlock
        echo   VLM service started (port 18081, text-only)
    )
) else (
    echo   [SKIP] VLM model not found
)

echo.
echo ============================================================
echo   Services started!
echo.
echo   LLM API:  http://127.0.0.1:18080/v1/chat/completions
echo   VLM API:  http://127.0.0.1:18081/v1/chat/completions
echo.
echo   Run the brain: 启动网页版.bat
echo ============================================================
echo.
echo Press any key to close this window (services stay running)...
pause >nul
