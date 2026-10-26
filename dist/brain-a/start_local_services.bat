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

:: ---------------------------------------------------------------------------
:: Fix (2026-10-08): this script could never start either service.
::   1) It launched llama\llama-server.exe, which does NOT exist in llama\ - this
::      build ships llama\llama.exe with a `serve` subcommand (same fallback
::      LLMClient.js already implements). cmd printed "not recognized".
::   2) -ngl 99 + --mlock + -c 16384 assume a CUDA GPU box. On a CPU-only
::      machine --mlock pins the whole 8.8GB GGUF into physical RAM and 16k ctx
::      adds ~2.6GB KV cache; measured here: ready in 81s only with
::      -ngl 0 / -c 2048 / mmap. So GPU is now detected, flags follow the result.
::   3) VLM looked for mmproj-qwen3-vl-8b-f16.gguf; the file on disk is
::      mmproj-F16.gguf, so vision always degraded to text-only silently.
:: ---------------------------------------------------------------------------
set "LLAMA_EXE=llama\llama-server.exe"
set "LLAMA_PRE="
if not exist "llama\llama-server.exe" set "LLAMA_EXE=llama\llama.exe"
if not exist "llama\llama-server.exe" set "LLAMA_PRE=serve"
if not exist "%LLAMA_EXE%" (
    echo   [FAIL] neither llama\llama-server.exe nor llama\llama.exe found
    goto :eof
)

set "NGL=0"
set "CTX=2048"
set "BSIZE=512"
set "MLOCK="
nvidia-smi -L >nul 2>&1
if %errorlevel%==0 (
    set "NGL=99"
    set "CTX=8192"
    set "BSIZE=1024"
    set "MLOCK=--mlock"
    echo   GPU detected: -ngl 99 -c 8192 --mlock
) else (
    echo   CPU-only box: -ngl 0 -c 2048, mmap kept, no --mlock ^(loading takes ~80s^)
)

:: Start LLM (Qwen3-14B) on port 18080
if exist "models\llm\qwen3-14b-instruct-q4_k_m.gguf" (
    start "SomaOS-LLM" /MIN "%LLAMA_EXE%" %LLAMA_PRE% ^
        -m models\llm\qwen3-14b-instruct-q4_k_m.gguf ^
        --port 18080 ^
        --host 127.0.0.1 ^
        -ngl %NGL% ^
        -c %CTX% ^
        -t %NUMBER_OF_PROCESSORS% ^
        -b %BSIZE% %MLOCK%
    echo   LLM service started (port 18080) via %LLAMA_EXE% %LLAMA_PRE%
) else (
    echo   [SKIP] LLM model not found
)

:: Start VLM (Qwen3-VL-8B) on port 18081
echo [4/4] Starting VLM Service (Qwen3-VL-8B) on port 18081...

if exist "models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf" (
    if exist "models\vlm\mmproj-F16.gguf" (
        start "SomaOS-VLM" /MIN "%LLAMA_EXE%" %LLAMA_PRE% ^
            -m models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf ^
            --mmproj models\vlm\mmproj-F16.gguf ^
            --port 18081 ^
            --host 127.0.0.1 ^
            -ngl %NGL% ^
            -c %CTX% ^
            -t %NUMBER_OF_PROCESSORS% ^
            -b %BSIZE% %MLOCK%
        echo   VLM service started (port 18081)
    ) else (
        echo   [WARN] VLM mmproj not found, starting VLM in text-only mode
        start "SomaOS-VLM" /MIN "%LLAMA_EXE%" %LLAMA_PRE% ^
            -m models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf ^
            --port 18081 ^
            --host 127.0.0.1 ^
            -ngl %NGL% ^
            -c %CTX% ^
            -t %NUMBER_OF_PROCESSORS% ^
            -b %BSIZE% %MLOCK%
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
