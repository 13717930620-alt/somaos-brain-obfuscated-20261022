@echo off
chcp 65001 >nul
setlocal
title SomaOS Brain Next - Local Inference Services
cd /d "%~dp0"

call setup_junction.bat

set "LLM_MODEL=models\llm\qwen3-14b-instruct-q4_k_m.gguf"
set "VLM_MODEL=models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf"
set "VLM_MMPROJ=models\vlm\mmproj-F16.gguf"
set "LLAMA_SERVER=llama\llama.exe"
set "LLAMA_RUN=%LLAMA_SERVER%"

if exist "C:\somaos_test\llama\llama.exe" (
    set "LLAMA_RUN=C:\somaos_test\llama\llama.exe"
    set "LLM_MODEL=C:\somaos_test\models\llm\qwen3-14b-instruct-q4_k_m.gguf"
    set "VLM_MODEL=C:\somaos_test\models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf"
    set "VLM_MMPROJ=C:\somaos_test\models\vlm\mmproj-F16.gguf"
)

if not exist "%LLAMA_SERVER%" (
  echo [ERROR] Missing %LLAMA_SERVER%
  pause
  exit /b 1
)
if not exist "models\llm\qwen3-14b-instruct-q4_k_m.gguf" (
  echo [ERROR] Missing LLM model
  pause
  exit /b 1
)
if not exist "models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf" (
  echo [ERROR] Missing VLM model
  pause
  exit /b 1
)
if not exist "models\vlm\mmproj-F16.gguf" (
  echo [ERROR] Missing VLM mmproj
  pause
  exit /b 1
)

echo Starting local LLM on http://127.0.0.1:18080/v1
start "SomaOS Local LLM" /MIN "%LLAMA_RUN%" serve -m "%LLM_MODEL%" --host 127.0.0.1 --port 18080 -ngl 99 -c 8192 -t 6 -b 1024

echo Starting local VLM on http://127.0.0.1:18081/v1
start "SomaOS Local VLM" /MIN "%LLAMA_RUN%" serve -m "%VLM_MODEL%" --mmproj "%VLM_MMPROJ%" --host 127.0.0.1 --port 18081 -ngl 99 -c 4096 -t 4 -b 512

set "SOMAOS_LOCAL_LLM_URL=http://127.0.0.1:18080/v1"
set "SOMAOS_LOCAL_VLM_URL=http://127.0.0.1:18081/v1"
echo.
echo Local inference services started.
echo LLM health: http://127.0.0.1:18080/health
echo VLM health: http://127.0.0.1:18081/health
endlocal
